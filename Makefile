# Compiler & Flags
NVCC = nvcc

OPENCV_PATH = ../build_opencv

CXXFLAGS = -I$(OPENCV_PATH)/include/opencv4
LDFLAGS = -L$(OPENCV_PATH)/lib64 -lopencv_core -lopencv_imgcodecs -lopencv_highgui -lopencv_imgproc -lcudart

# Object files
OBJECTS = cpu gpu1 gpu2 gpu3

# Default target
all: $(OBJECTS)

# CPU Implementation
cpu: sobelWithCpu.cu
	$(NVCC) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

# GPU Implementations
gpu1: sobelWithNoOrganization.cu
	$(NVCC) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

gpu2: sobelWithMul.cu
	$(NVCC) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

gpu3: sobelWithShmemBlocking.cu
	$(NVCC) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

# Clean
clean:
	rm -f $(OBJECTS)

