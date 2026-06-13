---
name: opencv-experiment
description: Complete OpenCV image processing experiments from assignment images — parse requirements, write C++/Python code, compile with MinGW, run, and verify output images.
---

# OpenCV Experiment Completion Workflow

Complete OpenCV image processing experiments when the user provides an assignment image. This is a repeatable academic workflow seen across multiple sessions.

## When To Use

- User provides an image of an OpenCV experiment assignment
- User asks to "完成这个实验" (complete this experiment)
- User provides C++ or Python OpenCV code snippets to expand

## Workflow

### Step 1: Read and Parse the Experiment Image

1. Read the provided image file (typically `E:\opencv.jpeg` or user-specified path)
2. Extract the experiment requirements from the image text:
   - 实验目的 (experiment objectives)
   - 实验要求 (experiment requirements)
   - 测试数据 (test data)
   - Expected outputs (screenshots, code)
3. List all sub-tasks that need to be completed

### Step 2: Check Development Environment

Run these checks in order:

```bash
# Check for g++ compiler
where g++ 2>/dev/null && g++ --version 2>/dev/null | head -1

# Common g++ locations on this machine:
# - D:\QT\Tools\mingw1310_64\bin\g++.exe

# Check for OpenCV installation
ls "D:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/include/"
ls "D:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/x64/mingw/bin/"

# Check for Python OpenCV
python -c "import cv2; print(cv2.__version__)"
```

**Known paths on this machine:**
- g++: `D:\QT\Tools\mingw1310_64\bin\g++.exe`
- OpenCV MinGW build: `D:\OpenCV-MinGW-Build-OpenCV-4.5.2-x64\`
- OpenCV DLLs: `D:\OpenCV-MinGW-Build-OpenCV-4.5.2-x64\x64\mingw\bin\`

### Step 3: Create Project Structure

For C++ experiments, create:
- Individual `.cpp` files per experiment method
- `CMakeLists.txt` for optional cmake builds
- `compile.bat` for direct MinGW compilation

### Step 4: Write Experiment Code

Follow the experiment requirements precisely. Common patterns:

**Mask Generation Methods:**
1. Grayscale traversal → binary mask (pixel-by-pixel threshold)
2. `cvtColor` + `inRange` → HSV color mask
3. `split` channel separation → single-channel mask

**Matting/Extraction Methods:**
1. `bitwise_and` with mask
2. Matrix multiplication (`multiply()`) with mask
3. Equivalence verification (pixel-wise diff)

### Step 5: Compile (C++)

Use the MinGW compiler directly with OpenCV include/lib paths:

```bash
"D:/QT/Tools/mingw1310_64/bin/g++.exe" -std=c++11 -O2 -Wall -o output.exe source.cpp \
  -I"D:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/include" \
  -L"D:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/x64/mingw/lib" \
  -lopencv_core -lopencv_imgproc -lopencv_highgui -lopencv_imgcodecs
```

### Step 6: Handle DLL Dependencies

**Critical:** Copy OpenCV DLLs to the working directory before running:

```bash
cp "D:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/x64/mingw/bin/"*.dll D:/output_dir/
```

Without this, executables will fail with DLL load errors.

### Step 7: Run and Verify

```bash
# Run in background (programs with imshow/waitKey block)
"D:/output_dir/output.exe" 2>&1

# Check generated output images
ls -la D:/output_dir/experiment_fig*.png
```

### Step 8: Present Results

- Open generated images with `start "" "path\to\image.png"`
- Summarize results in a table format
- Note any discrepancies or interesting findings

## Compile Script Template

Create a `compile.bat` for repeatable compilation:

```batch
@echo off
set "GPP=D:/QT/Tools/mingw1310_64/bin/g++.exe"
set "OCV_INC=-ID:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/include"
set "OCV_LIB=-LD:/OpenCV-MinGW-Build-OpenCV-4.5.2-x64/x64/mingw/lib"
set "OCV_LIBS=-lopencv_core -lopencv_imgproc -lopencv_highgui -lopencv_imgcodecs"

%GPP% -std=c++11 -O2 -Wall -o %1.exe %1.cpp %OCV_INC% %OCV_LIB% %OCV_LIBS%
if %errorlevel% neq 0 echo BUILD FAILED
```

## Common Pitfalls

1. **DLL not found at runtime** — Always copy DLLs to working directory
2. **imshow blocks execution** — Use `waitKey(0)` and run in background, or save to file instead
3. **Image path with Chinese characters** — Use forward slashes and verify path exists
4. **Large images cause slow processing** — Consider resizing for display, keep original for computation

## Output Format

Present results as:
- Summary table of methods and pixel counts
- Equivalence verification results (should show 0 differences)
- Generated image files listed with sizes
- Code location for user reference
