# Particle Map Image Generator

A gravitational basin visualization built with C++, CUDA, and OpenGL. The program simulates a test particle for each pixel and colors that pixel according to which gravitational attractor captures the particle.

This project explores gravity simulation, parallel computing with CUDA, and displaying simulation results using GLFW and OpenGL.

## Features

- Displays a basin image in a 1200 × 1200 window.
- Uses three fixed gravitational attractors, colored red, blue, and yellow.
- Runs the simulation on the GPU, with one CUDA thread per pixel.
- Allows keyboard control of the gravitational softening parameter, `softening`.
- Shows a fast preview while parameters are changing, then automatically renders a higher-quality image when the keys are released.
- Prints the current softening value and CUDA kernel execution time in the terminal.

## How It Works

1. Map each pixel to a position in world coordinates, from `-10` to `10` on both axes.
2. Place a test particle at that position with zero initial velocity.
3. Calculate the combined acceleration from the three attractors and update the particle's velocity and position at each time step.
4. If the particle enters an attractor's capture radius, color the pixel with that attractor's color.
5. If the particle escapes or reaches the step limit without being captured, color the pixel dark gray.
6. Copy the pixel data from the GPU to the CPU, upload it to an OpenGL texture, and display it.

The three attractors remain fixed, and test particles do not interact with one another. The image shows capture outcomes for different starting positions rather than animated particle trajectories.

## Project Files

| File | Purpose |
| --- | --- |
| `particleMapImagegenerator.cu` | Editable source code containing the physics simulation, CUDA kernel, window rendering, and keyboard controls |
| `build.bat` | Editable Windows build script that initializes the compiler environment, compiles the CUDA source, and copies the GLFW runtime library |
| `particleMapImageGenerator.exe` | Generated executable; rebuild it after changing the source code |
| `README.md` | Project overview, requirements, and instructions |
| `glfw3.dll` | GLFW runtime dependency copied into this folder by the build script; required to run the executable |

The source uses the `.cu` extension because it contains CUDA code and is compiled with `nvcc`.

## Requirements

- Windows.
- A CUDA-capable NVIDIA GPU with a compatible NVIDIA driver.
- CUDA Toolkit, which provides the `nvcc` compiler.
- Visual Studio C++ Build Tools for the Windows host compiler.
- GLFW and an OpenGL-capable graphics environment.

GLFW is installed through vcpkg in the current development environment. The build script uses this computer's Visual Studio and vcpkg installation paths; change those paths inside `build.bat` to match your own setup. The CUDA Toolkit's `bin` directory must be on your `PATH` so the script can find `nvcc`.

## Build and Run

Run the following commands in **Command Prompt (CMD)**.

Open the project directory and run the build script:

```cmd
cd /d "D:\codes\cudaParticleMapGenerator"
build.bat
```

The script automatically:

1. Changes to its own folder using `%~dp0`, so the build uses the correct directory even when called from elsewhere.
2. Initializes the Visual Studio C++ compiler environment.
3. Compiles `particleMapImagegenerator.cu` with `nvcc`, linking GLFW, OpenGL, and the required Windows libraries to produce `particleMapImageGenerator.exe`.
4. Copies `glfw3.dll` next to the executable.
5. Reports success or failure and pauses so you can read the output.

The source code, README, and build script are editable project files. The executable is generated during compilation, and the DLL is copied from the installed GLFW library. Re-run `build.bat` after changing the source code to update the executable.

After a successful build, press any key to return to the command prompt, then launch the program:

```cmd
particleMapImageGenerator.exe
```

The first image uses the quality settings, so allow time for the initial calculation to finish.

## Controls

With the program window focused, use the following controls:

| Key or Action | Effect |
| --- | --- |
| `Q` | Decrease `softening`, down to a minimum of `0.05` |
| `E` | Increase `softening` |
| `R` | Reset `softening` to `0.25` |
| Close the window | Exit the program |

Softening reduces the extreme acceleration that would otherwise occur near an attractor. Holding a control key continuously updates the parameter using preview settings. Releasing the keys triggers a render with the quality settings.

## Simulation Settings

| Parameter | Preview | Quality |
| --- | --- | --- |
| Maximum steps `maxSteps` | 15000 | 350000 |
| Capture radius `captureRadius` | 0.25 | 0.14 |
| Time step `dt` | 0.08 | 0.015 |
| Gravitational constant `G` | 1.0 | 1.0 |
| Escape radius `escapeRadius` | 28.0 | 40.0 |

Each attractor has a mass of `10.0`. Their positions are `(-5, 0)`, `(5, 0)`, and `(0, 4)`. These values use the project's simulation units.

Preview and quality modes use different simulation parameters, so capture outcomes and image details may differ between them.

## Current Limitations

- Images are displayed in the window; saving PNG, BMP, or other image files is not implemented.
- Changing the attractor count, positions, or masses requires editing and recompiling the source code.
- This numerical simulation uses discrete time steps. Results depend on the time step, capture radius, softening, and maximum step count.
- The reported kernel time measures only GPU kernel execution. It excludes data transfers, texture uploads, and window rendering.
