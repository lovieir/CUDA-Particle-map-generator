#include <iostream>
#include <cmath>
#include <GLFW/glfw3.h>

using namespace std;

struct pixel_c {
    unsigned char r;
    unsigned char g;
    unsigned char b;
};

struct vec 
{
    float vx;
    float vy;
};

struct coords
{
    float x;
    float y;
};

struct body
{
    coords pos;
    vec vel;
    float mass;
    pixel_c c;
};

struct setup
{
    int maxSteps;
    float captureRadius;
    float dt;
    float G;
    float escapeRadius;
};


const int height = 1200;
const int width = 1200;
const float worldMinX = -10.0f;
const float worldMaxX = 10.0f;
const float worldMinY = -10.0f;
const float worldMaxY = 10.0f;

__device__ coords getWorldCoords(coords pixelCoords, int width, int height, float worldMinX, float worldMaxX, float worldMinY, float worldMaxY) {
    float perc_x = pixelCoords.x / float(width - 1);
    float perc_y = pixelCoords.y / float(height - 1);

    return {
        worldMinX + perc_x * (worldMaxX - worldMinX),
        worldMinY + perc_y * (worldMaxY - worldMinY)
    };
}

__device__ float getDistance(coords a, coords b){
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
}

__device__ float getDistanceSquared(coords a, coords b){
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    return dx * dx + dy * dy;
}

__device__ int getCapturedBodyIndex(coords pos_p, body bodies[], float captureRadius, int bodyCount){
    for (int i = 0; i < bodyCount; i++){
        float distSquared = getDistanceSquared(pos_p, bodies[i].pos);
        if (distSquared < captureRadius * captureRadius){
            return i;
        }
    }
    return -1;
} 

__device__ vec getAccelerationFrom(coords pos_p, body a, float G, float softening){
    
    float dx = a.pos.x - pos_p.x;
    float dy = a.pos.y - pos_p.y;

    float distSquared = dx * dx + dy * dy + softening * softening;
    float distance = sqrt(distSquared);

    float directionX = dx / distance;
    float directionY = dy / distance;

    float accAmount = G * a.mass / distSquared;

    vec acc;
    acc.vx = directionX * accAmount;
    acc.vy = directionY * accAmount;

    return acc;
}

__device__ vec getTotalAcceleration(coords pos_p, body bodies[], int bodyCount, float G, float softening){
    
    vec acc_t;
    acc_t.vx = 0.0f;
    acc_t.vy = 0.0f;

    for (int i = 0; i < bodyCount; i++){
        vec acc_b = getAccelerationFrom(pos_p, bodies[i], G, softening);
        acc_t.vx += acc_b.vx;
        acc_t.vy += acc_b.vy;
    }

    return acc_t;
}

__device__ int simulateParticle(coords pos_p, vec vel_p, body bodies[], int maxSteps, float captureRadius, int bodyCount, float dt, float G, float softening, float escapeRadius){

    for (int i = 0; i < maxSteps; i++){

        float distFromCenterSquared = pos_p.x * pos_p.x + pos_p.y * pos_p.y;

        int capturedIndex = getCapturedBodyIndex(pos_p, bodies, captureRadius, bodyCount);
        if (capturedIndex != -1 || distFromCenterSquared >= escapeRadius * escapeRadius) {
            return capturedIndex;
        }

        vec acc_t = getTotalAcceleration(pos_p, bodies, bodyCount, G, softening);
        
        vel_p.vx += acc_t.vx * dt;
        vel_p.vy += acc_t.vy * dt;
        pos_p.x += vel_p.vx * dt;
        pos_p.y += vel_p.vy * dt;
    }

    return -1;
}

__global__ void fillBasinsKernel(pixel_c* pixels, body* bodies, int bodyCount, int width, int height, int maxSteps, float captureRadius, float dt, float G, float softening, float escapeRadius, float worldMinX, float worldMaxX, float worldMinY, float worldMaxY){
    int px = blockIdx.x * blockDim.x + threadIdx.x;
    int py = blockIdx.y * blockDim.y + threadIdx.y;

    if (px >= width || py >= height) {
        return;
    }

    int index = py * width + px;

    coords pixelCoords = {float(px), float(py)};
    coords worldCoords = getWorldCoords(pixelCoords, width, height, worldMinX, worldMaxX, worldMinY, worldMaxY);
    coords pos_p = worldCoords;
    vec vel_p = {0.0f, 0.0f};

    int capturedIndex = simulateParticle(pos_p, vel_p, bodies, maxSteps, captureRadius, bodyCount, dt, G, softening, escapeRadius);

    if (capturedIndex == -1) {
        pixels[index] = {20, 20, 20};
    } else {
        pixels[index] = bodies[capturedIndex].c;
    }
}

void renderBasins(pixel_c* pixels, pixel_c* devicePixels, body* deviceBodies, int bodyCount, int width, int height, int maxSteps, float captureRadius, float dt, float G, float softening, float escapeRadius, float worldMinX, float worldMaxX, float worldMinY, float worldMaxY, GLuint texture){
    
    dim3 block(16, 16);

    dim3 grid(
        (width + block.x - 1) / block.x,
        (height + block.y - 1) / block.y
    );

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);

    fillBasinsKernel<<<grid, block>>>(devicePixels, deviceBodies, bodyCount, width, height, maxSteps, captureRadius, dt, G, softening, escapeRadius, worldMinX, worldMaxX, worldMinY, worldMaxY);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float milliseconds = 0.0f;
    cudaEventElapsedTime(&milliseconds, start, stop);

    cout << "CUDA kernel time: " << milliseconds << " ms\n";

    cudaMemcpy(
        pixels,
        devicePixels,
        width * height * sizeof(pixel_c),
        cudaMemcpyDeviceToHost
    );
    
    glBindTexture(GL_TEXTURE_2D, texture);

    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
}

int main() {

    /*Setups*/

    setup quality;
    quality.maxSteps = 350000;
    quality.captureRadius = 0.14f;
    quality.dt = 0.015f;
    quality.G = 1.0f;
    quality.escapeRadius = 40.0f;

    setup preview;
    preview.maxSteps = 15000;
    preview.captureRadius = 0.25f;
    preview.dt = 0.08f;
    preview.G = 1.0f;
    preview.escapeRadius = 28.0f;
    
    /*Main Builds*/

    body bodies[3] = {
        {{-5.0f, 0.0f}, {0.0f, 0.0f}, 10.0f, {255, 45, 85}},
        {{5.0f, 0.0f}, {0.0f, 0.0f}, 10.0f, {40, 180, 255}},
        {{0.0f, 4.0f}, {0.0f, 0.0f}, 10.0f, {255, 220, 80}}
    };

    int bodyCount = 3;
    float softening = 0.25f;
    bool rerender = true;
    bool firstRender = true;
    bool isChanging = false;
    bool wasChanging = false;

    body* deviceBodies;
    cudaMalloc(&deviceBodies, bodyCount * sizeof(body));
    cudaMemcpy(deviceBodies, bodies, bodyCount * sizeof(body), cudaMemcpyHostToDevice);

    if (!glfwInit()) {
        cout << "\nFail to initialize GLFW.";
        return 0;
    }

    GLFWwindow* window = glfwCreateWindow(width, height, "Gravity", NULL, NULL);

    if (!window) {
        cout << "\nFailed to create window.";
        glfwTerminate();
        return 0;
    }

    glfwMakeContextCurrent(window);

    static pixel_c pixels[width * height];

    pixel_c* devicePixels;

    cudaMalloc(&devicePixels, width * height * sizeof(pixel_c));

    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, pixels);

    while (!glfwWindowShouldClose(window)) {

        isChanging = false;

        if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS) {
            softening -= 0.05f;
            rerender = true;
            isChanging = true;
        }

        if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS) {
            softening += 0.05f;
            rerender = true;
            isChanging = true;
        }

        if (glfwGetKey(window, GLFW_KEY_R) == GLFW_PRESS){
            softening = 0.25f;
            rerender = true;
            isChanging = true;
        }

        if (softening < 0.05f) {
            softening = 0.05f;
        }
        
        if (firstRender){
            cout << "softening: " << softening << "\n";
            renderBasins(pixels, devicePixels, deviceBodies, bodyCount, width, height, quality.maxSteps, quality.captureRadius, quality.dt, quality.G, softening, quality.escapeRadius, worldMinX, worldMaxX, worldMinY, worldMaxY, texture);
            firstRender = false;
            rerender = false;
        }
        
        bool justStoppedChanging = !isChanging && wasChanging;

        if (justStoppedChanging) {
            rerender = true;
        }

        if (rerender) {

            if (isChanging){
                cout << "softening: " << softening << "\n";
                renderBasins(pixels, devicePixels, deviceBodies, bodyCount, width, height, preview.maxSteps, preview.captureRadius, preview.dt, preview.G, softening, preview.escapeRadius, worldMinX, worldMaxX, worldMinY, worldMaxY, texture);
                rerender = false;
            }
            else if (justStoppedChanging){
                cout << "softening: " << softening << "\n";
                renderBasins(pixels, devicePixels, deviceBodies, bodyCount, width, height, quality.maxSteps, quality.captureRadius, quality.dt, quality.G, softening, quality.escapeRadius, worldMinX, worldMaxX, worldMinY, worldMaxY, texture);
                rerender = false;
            }            
        }

        wasChanging = isChanging;

        glClearColor(0.02f, 0.02f, 0.04f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, texture);

        glBegin(GL_QUADS);

        glTexCoord2f(0.0f, 0.0f);
        glVertex2f(-1.0f, -1.0f);

        glTexCoord2f(1.0f, 0.0f);
        glVertex2f(1.0f, -1.0f);

        glTexCoord2f(1.0f, 1.0f);
        glVertex2f(1.0f, 1.0f);

        glTexCoord2f(0.0f, 1.0f);
        glVertex2f(-1.0f, 1.0f);

        glEnd();
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    cudaFree(devicePixels);
    cudaFree(deviceBodies);
    glfwDestroyWindow(window);
    glfwTerminate();
    
    return 0;
}