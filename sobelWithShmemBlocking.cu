#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda.h>
#include <device_functions.h>
//#include <cstdio>
#include <opencv2/opencv.hpp>
#include <opencv2/core/core.hpp> 
#include <opencv2/highgui/highgui.hpp>
#include <iostream>

//named space for opencv and cout
using namespace std;
using namespace cv;

//kernel function for gpu
/*
* components for the kernel function:
* inout image data
* output image data
* image height
* image width
* transfer matrix in x direction
* transfer matrix in y direction
*/


#define TILE_SIZE 32  // Tile size for shared memory optimization
#define SOBEL_FILTER_SIZE 3  // Sobel kernel is 3x3

__global__ void sobelGpu(
    const unsigned char *__restrict__ input, 
    unsigned char *__restrict__ output, 
    int imgH, int imgW, 
    const int *__restrict__ d_sobel_x, 
    const int *__restrict__ d_sobel_y
) {
    // Shared memory block (TILE_SIZE + 2 for boundary pixels)
    __shared__ unsigned char sharedMem[TILE_SIZE + 2][TILE_SIZE + 2];

    // Compute global pixel coordinates
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int local_x = threadIdx.x + 1;  // Offset by 1 for halo region
    int local_y = threadIdx.y + 1;
    // Load data into shared memory (avoid out-of-bounds reads)
    if (x < imgW && y < imgH) {
        sharedMem[local_y][local_x] = input[y * imgW + x];
    }
    // Load halo region
    // Top edge
    if (threadIdx.y == 0 && y > 0) {
        sharedMem[0][local_x] = input[(y - 1) * imgW + x];
    }
    // Bottom edge
    if (threadIdx.y == blockDim.y - 1 && y < imgH - 1) {
        sharedMem[local_y + 1][local_x] = input[(y + 1) * imgW + x];
    }
    // Left edge
    if (threadIdx.x == 0 && x > 0) {
        sharedMem[local_y][0] = input[y * imgW + (x - 1)];
    }
    // Right edge
    if (threadIdx.x == blockDim.x - 1 && x < imgW - 1) {
        sharedMem[local_y][local_x + 1] = input[y * imgW + (x + 1)];
    }
    
    __syncthreads();  // Synchronize threads to ensure data is loaded

    // Compute Sobel only if inside the valid region (excluding edges)
    // Compute Sobel only for valid pixels
    if (x < imgW && y < imgH) {
        int Gx = 0, Gy = 0;
        
        // Apply Sobel kernel
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                int pixel = sharedMem[local_y + i][local_x + j];
                Gx += d_sobel_x[(i + 1) * SOBEL_FILTER_SIZE + (j + 1)] * pixel;
                Gy += d_sobel_y[(i + 1) * SOBEL_FILTER_SIZE + (j + 1)] * pixel;
            }
        }
        
        // Compute final edge magnitude
        int sum = min(255, abs(Gx) + abs(Gy));
        // Write to output
        output[y * imgW + x] = static_cast<unsigned char>(sum);
    }
}
// the main function
int main() {
    
    //read the input image, and transfer it in grayscal
    Mat gray_img = imread("test01.jpg", 0);

    // save the gray image
    /*
    save the gray image if needed
    */
    //imwrite("Gray_Image.jpg", gray_img);

    //transfer matrix
    int sobel_x[3][3];
    int sobel_y[3][3];

    //image size, height and width
    int imgH = gray_img.rows;
    int imgW = gray_img.cols;
    
    //initialze the image after gauss filter
    Mat gaussImg;
    //implementation of the gauss filter with a 3 X 3 kernel
    GaussianBlur(gray_img, gaussImg, Size(3, 3), 0, 0, BORDER_DEFAULT);
    // save the gauss image
    /*
    save the image after gauss filter if needed
    */
    //imwrite("gauss.jpg", gaussImg);

    // assign values to the x direction
    sobel_x[0][0] = -1; sobel_x[0][1] = 0; sobel_x[0][2] =1;
    sobel_x[1][0] = -2; sobel_x[1][1] = 0; sobel_x[1][2] =2;
    sobel_x[2][0] = -1; sobel_x[2][1] = 0; sobel_x[2][2] =1;
    // asign values to the y direction
    sobel_y[0][0] = -1; sobel_y[0][1] = -2; sobel_y[0][2] = -1;
    sobel_y[1][0] = 0; sobel_y[1][1] = 0; sobel_y[1][2] = 0;
    sobel_y[2][0] = 1; sobel_y[2][1] = 2; sobel_y[2][2] = 1;

    //the image for data after processed by GPU
    Mat out_img(imgH, imgW, CV_8UC1, Scalar(0));
    

    /*
    implemetation for GPU kernel
    */

    //device variables for transfer matrixes
    int *d_sobel_x;
    int *d_sobel_y;

    //device memory
    unsigned char *d_in;
    unsigned char *d_out;

    //recording the time
    cudaEvent_t start, stop;
    cudaEventCreate( &start );
    cudaEventCreate( &stop );
    //start recording
    cudaEventRecord( start, 0 );

    //memory allocate
    cudaMalloc((void**)&d_in, imgH * imgW * sizeof(unsigned char));
    cudaMalloc((void**)&d_out, imgH * imgW * sizeof(unsigned char));
    cudaMalloc((void**)&d_sobel_x, 9 * sizeof(int));
    cudaMalloc((void**)&d_sobel_y, 9 * sizeof(int));

    //pass the image data into the GPU
    cudaMemcpy(d_in, gaussImg.data, imgH * imgW * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy((void*)d_sobel_x, (void*)sobel_x, 3 *3* sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy((void*)d_sobel_y, (void*)sobel_y, 3 *3* sizeof(int), cudaMemcpyHostToDevice);
    
    //dim3 threadsPerBlock(32, 32);
    //dim3 blocksPerGrid((imgW + threadsPerBlock.x - 1) / threadsPerBlock.x, (imgH + threadsPerBlock.y - 1) / threadsPerBlock.y);

    //define the dimentions
    dim3 blocks((int)((imgW+15)/16), (int)(imgH+15)/16);
    dim3 threads(32, 32);

    //call the kernel function
    sobelGpu <<<blocks,threads>>> (d_in, d_out, imgH, imgW, d_sobel_x, d_sobel_y);
    //sobelInCuda3 <<< 1,1 >>> (d_in, d_out, imgH, imgW);

    //pass the output image data back to host
    cudaMemcpy(out_img.data, d_out, imgH * imgW * sizeof(unsigned char), cudaMemcpyDeviceToHost);

    //stop recording time
    cudaEventRecord( stop, 0 );
    cudaEventSynchronize( stop );

    //free memory
    cudaFree(d_in);
    cudaFree(d_out);

    //compute the time for execution
    float elapsedTime;
    cudaEventElapsedTime( &elapsedTime, start, stop );
    cout << "Time for execution with organized threads and block dimention is: " << static_cast<double>(elapsedTime) << " ms." <<endl;
    //printf( "The time for execution with ognized threads and block dimentions: %.6f ms \n", elapsedTime);
    cudaEventDestroy( start );
    cudaEventDestroy( stop );

    //save the output image
    imwrite("gpu3.jpg", out_img);

    return 0;
}
