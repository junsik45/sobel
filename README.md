[//]: # (Image References)

[image1]: ./outputs/cpu.jpg
[image2]: ./outputs/gpu1.jpg
[image3]: ./outputs/gpu2.jpg
[image4]: ./outputs/gpu3.jpg
[image5]: ./outputs/opencv.jpg
[image6]: ./test01.jpg

# TO DO:

Start from existing code in https://github.com/SidSong01/Sobel-Operator-with-CUDA and implement an improved(possibly) algorithm using shmem blocking. Original implementation had cpu, gpu1, gpu2, which compares serial cpu, gpu, and parallel gpu. I added implementation for shared memory usage for parallel gpu code, and called gpu3.
 
# Overview:
---
This is a project comparing the speed difference between the CPU and GPU implementation on Sobel Operator. For CPU implementation, OpenCV package and CPU computing on pixels have been tried. For GPU implementation, CUDA is used and different arrangement for the threads and blocks have been tried.

# How to run:
---
Make sure you have installed OpenCV and put correct path into Makefile. Then, 

* Compile:

	`$ make`

* Run:

	`$./gpu3`

# Results:
---
* The test image: 

![alt text][image6]

Size: 599 x 393

* CPU with OpenCV package:

![alt text][image5]

* CPU on pixels:

![alt text][image1]

* GPU implementation with 1 thread/block and 1 block/grid:

![alt text][image2]

* GPU implementation with organized dimensions:

`blocks((int)((imgW+31)/32),(int)(g_imgHeight+31)/32);`
`threads(16, 16);`

![alt text][image3]

* GPU implementation with organized dimensions and with shmem:

`blocks((int)((imgW+31)/32),(int)(g_imgHeight+31)/32);`
`threads(16, 16);`

![alt text][image4]


----

* Speed difference

| Method       		|     Execution Time (ms)	       | 
|:---------------------:|:---------------------------------------------:| 
| OpenCV package        | 1.700   							| 
| CPU on pixels	| 12.545	|
| GPU with single thread and block | 66.028 		|
| GPU with multiple threads and blocks | 0.528		|
| GPU with multiple threads and blocks + SHMEM | 0.528		|

