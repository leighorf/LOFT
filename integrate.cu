#include <iostream>
#include <stdio.h>
#include "datastructs.cu"
#include "macros.cpp"
#include "interp.cu"
#ifndef INTEGRATE_CU
#define INTEGRATE_CU

using namespace std;
// this is an error checking helper function for processes
// that run on the GPU. Without calling this, the GPU can
// fail to execute but the program won't crash or report it.
#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      cout << cudaGetErrorString(code) << endl;
      if (abort) exit(code);
   }
}



/* Compute the x component of vorticity. After this is called by the calvort kernel, you must also run 
   the kernel for applying the lower boundary condition and then the kernel for averaging to the
   scalar grid. */
__device__ void calc_xvort(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *vstag = data->v_4d_chunk;
    float *wstag = data->w_4d_chunk;
    float *dum0 = data->tem1_4d_chunk;

    float dwdy = ( ( WA4D(i, j, k, t) - WA4D(i, j-1, k, t) )/grid->dy ) * VF(j);
    float dvdz = ( ( VA4D(i, j, k, t) - VA4D(i, j, k-1, t) )/grid->dz ) * MF(k);
    TEM4D(i, j, k, t) = dwdy - dvdz; 
}

/* Compute the y component of vorticity. After this is called by the calvort kernel, you must also run 
   the kernel for applying the lower boundary condition and then the kernel for averaging to the
   scalar grid. */
__device__ void calc_yvort(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *ustag = data->u_4d_chunk;
    float *wstag = data->w_4d_chunk;
    float *dum0 = data->tem2_4d_chunk;

    float dwdx = ( ( WA4D(i, j, k, t) - WA4D(i-1, j, k, t) )/grid->dx ) * UF(i);
    float dudz = ( ( UA4D(i, j, k, t) - UA4D(i, j, k-1, t) )/grid->dz ) * MF(k);
    TEM4D(i, j, k, t) = dudz - dwdx;
}

/* Compute the z component of vorticity. After this is called by the calvort kernel, you must also run 
   the kernel for applying the lower boundary condition and then the kernel for averaging to the
   scalar grid. */
__device__ void calc_zvort(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *ustag = data->u_4d_chunk;
    float *vstag = data->v_4d_chunk;
    float *dum0 = data->tem3_4d_chunk;

    float dvdx = ( ( VA4D(i, j, k, t) - VA4D(i-1, j, k, t) )/grid->dx) * UF(i);
    float dudy = ( ( UA4D(i, j, k, t) - UA4D(i, j-1, k, t) )/grid->dy) * VF(j);
    TEM4D(i, j, k, t) = dvdx - dudy;
}

/* Compute the X component of vorticity tendency due
   to tilting Y and Z components into the X direction */
__device__ void calc_xvort_tilt(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];
}

/* Compute the Y component of vorticity tendency due
   to tilting X and Z components into the X direction */
__device__ void calc_yvort_tilt(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];
}

/* Compute the Z component of vorticity tendency due
   to tilting X and Y components into the X direction */
__device__ void calc_zvort_tilt(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *ustag = data->u_4d_chunk;
    float *vstag = data->v_4d_chunk;
    float *wstag = data->w_4d_chunk;

    // Compute dw/dx and put it in the tem1 array. The derivatives
    // land on weird places so we have to average each derivative back
    // to the scalar grid, resulting in this clunky approach
    float *dum0 = data->tem1_4d_chunk;
    TEM4D(i, j, k, t) = ( ( WA4D(i, j, k, t) - WA4D(i-1, j, k, t) ) / grid->dx ) * UF(i);

    // put dv/dz in tem2
    dum0 = data->tem2_4d_chunk;
    TEM4D(i, j, k, t) = ( ( VA4D(i, j, k, t) - VA4D(i, k, k-1, t) ) / grid->dz ) * MF(k);

    // put dw/dy in tem3
    dum0 = data->tem3_4d_chunk;
    TEM4D(i, j, k, t) = ( ( WA4D(i, j, k, t) - WA4D(i, j-1, k, t) ) / grid->dy ) * VF(j);

    // put du/dz in tem4
    dum0 = data->tem4_4d_chunk;
    TEM4D(i, j, k, t) = ( ( UA4D(i, j, k, t) - UA4D(i, j, k-1, t) ) / grid->dz ) * MF(k);
}

/* Compute the X component of vorticity tendency due
   to stretching of the vorticity along the X axis. */
__device__ void calc_xvort_stretch(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *vstag = data->v_4d_chunk;
    float *wstag = data->w_4d_chunk;
    float *xvort = data->xvort_4d_chunk;
    float *xvort_stretch = data->xvstretch_4d_chunk;

    // this stencil conveniently lands itself on the scalar grid,
    // so we won't have to worry about doing any averaging. I think.
    float *buf0 = xvort;
    float xv = BUF4D(i, j, k, t);
    float dvdy = ( ( VA4D(i, j, k, t) - VA4D(i, j-1, k, t) )/grid->dy) * VF(j);
    float dwdz = ( ( WA4D(i, j, k, t) - WA4D(i, j, k-1, t) )/grid->dz) * MF(k);

    buf0 = xvort_stretch;
    BUF4D(i, j, k, t) = -1.*xv*( dvdy + dwdz);

}

/* Compute the Y component of vorticity tendency due
   to stretching of the vorticity along the Y axis. */
__device__ void calc_yvort_stretch(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *ustag = data->u_4d_chunk;
    float *wstag = data->w_4d_chunk;
    float *yvort = data->yvort_4d_chunk;
    float *yvort_stretch = data->yvstretch_4d_chunk;

    // this stencil conveniently lands itself on the scalar grid,
    // so we won't have to worry about doing any averaging. I think.
    float *buf0 = yvort;
    float yv = BUF4D(i, j, k, t);
    float dudx = ( ( UA4D(i, j, k, t) - UA4D(i-1, j, k, t) )/grid->dx) * UF(i);
    float dwdz = ( ( WA4D(i, j, k, t) - WA4D(i, j, k-1, t) )/grid->dz) * MF(k);

    buf0 = yvort_stretch;
    BUF4D(i, j, k, t) = -1.*yv*( dudx + dwdz);
}

/* Compute the Z component of vorticity tendency due
   to stretching of the vorticity along the Z axis. */
__device__ void calc_zvort_stretch(datagrid *grid, integration_data *data, int *idx_4D, int NX, int NY, int NZ) {
    int i = idx_4D[0];
    int j = idx_4D[1];
    int k = idx_4D[2];
    int t = idx_4D[3];

    float *ustag = data->u_4d_chunk;
    float *vstag = data->v_4d_chunk;
    float *zvort = data->zvort_4d_chunk;
    float *zvort_stretch = data->zvstretch_4d_chunk;

    // this stencil conveniently lands itself on the scalar grid,
    // so we won't have to worry about doing any averaging. I think.
    float *buf0 = zvort;
    float zv = BUF4D(i, j, k, t);
    float dudx = ( ( UA4D(i, j, k, t) - UA4D(i-1, j, k, t) )/grid->dx) * UF(i);
    float dvdy = ( ( VA4D(i, j, k, t) - VA4D(i, j-1, k, t) )/grid->dy) * VF(j);

    buf0 = zvort_stretch;
    BUF4D(i, j, k, t) = -1.*zv*( dudx + dvdy);
}

/* When doing the parcel trajectory integration, George Bryan does
   some fun stuff with the lower boundaries of the arrays, presumably
   to prevent the parcels from exiting out the bottom of the domain
   or experience artificial values */
__global__ void applyMomentumBC(float *ustag, float *vstag, float *wstag, int NX, int NY, int NZ, int tStart, int tEnd) {
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    // this is done for easy comparison to CM1 code
    int ni = NX; int nj = NY;

    // this is a lower boundary condition, so only when k is 0
    // also this is on the u staggered mesh
    if (( j < nj+1) && ( i < ni+1) && ( k == 0)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the u stagger macro to handle the
            // proper indexing
            //UA4D(i, j, 0, tidx) = UA4D(i, j, 1, tidx);

            // I commented these out because in George's 
            // code, this index is actually for Z=0, but
            // in these arrays, it's on the scalar mesh
            // so doesn't quite work that way. 
        }
    }
    
    // do the same but now on the v staggered grid
    if (( j < nj+1) && ( i < ni+1) && ( k == 0)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the v stagger macro to handle the
            // proper indexing
            //VA4D(i, j, 0, tidx) = VA4D(i, j, 1, tidx);
        }
    }

    // do the same but now on the w staggered grid
    if (( j < nj+1) && ( i < ni+1) && ( k == 0)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the w stagger macro to handle the
            // proper indexing
            WA4D(i, j, 0, tidx) = -1*WA4D(i, j, 2, tidx);
        }
    }
}


__global__ void calcvort(datagrid *grid, integration_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int idx_4D[4];
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    //printf("%i, %i, %i\n", i, j, k);

    idx_4D[0] = i; idx_4D[1] = j; idx_4D[2] = k;
    if ((i < NX) && (j < NY+1) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_xvort(grid, data, idx_4D, NX, NY, NZ);
        }
    }

    if ((i < NX+1) && (j < NY) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_yvort(grid, data, idx_4D, NX, NY, NZ);
        }
    }
    if ((i < NX+1) && (j < NY+1) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_zvort(grid, data, idx_4D, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the Vorticity Equation */
__global__ void calcvortstretch(datagrid *grid, integration_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int idx_4D[4];
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    //printf("%i, %i, %i\n", i, j, k);

    idx_4D[0] = i; idx_4D[1] = j; idx_4D[2] = k;
    if ((i < NX) && (j < NY+1) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_xvort_stretch(grid, data, idx_4D, NX, NY, NZ);
        }
    }

    if ((i < NX+1) && (j < NY) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_yvort_stretch(grid, data, idx_4D, NX, NY, NZ);
        }
    }
    if ((i < NX+1) && (j < NY+1) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_zvort_stretch(grid, data, idx_4D, NX, NY, NZ);
        }
    }
}

/* Compute the forcing tendencies from the Vorticity Equation */
__global__ void calczvorttilt(datagrid *grid, integration_data *data, int tStart, int tEnd) {
    // get our 3D index based on our blocks/threads
    int i = (blockIdx.x*blockDim.x) + threadIdx.x;
    int j = (blockIdx.y*blockDim.y) + threadIdx.y;
    int k = (blockIdx.z*blockDim.z) + threadIdx.z;
    int idx_4D[4];
    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    //printf("%i, %i, %i\n", i, j, k);

    idx_4D[0] = i; idx_4D[1] = j; idx_4D[2] = k;
    if ((i < NX+1) && (j < NY+1) && (k > 0) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            idx_4D[3] = tidx;
            calc_zvort_tilt(grid, data, idx_4D, NX, NY, NZ);
        }
    }
}


/* Apply the free-slip lower boundary condition to the vorticity field. */
__global__ void applyVortBC(datagrid *grid, integration_data *data, int tStart, int tEnd) {
    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *dum0;

    // NOTE: Not sure if need to use BUF4D or TEM4D. The size of the array
    // will for sure be respected by BUF4D but unsure if it even matters here.

    // This is a lower boundary condition, so only when k is 0.
    // Start with xvort. 
    if (( i < NX) && ( j < NY+1) && ( k == 0)) {
        // at this stage, xvort is in the tem1 array
        dum0 = data->tem1_4d_chunk;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            TEM4D(i, j, 0, tidx) = TEM4D(i, j, 1, tidx);
            // I'm technically ignoring an upper boundary condition
            // here, but we never really guarantee that we're at
            // the top of the model domain because we do a lot of subsetting.
            // So, for now, we assume we're nowehere near the top. 
        }
    }
    
    // Do the same but now on the yvort array 
    if (( j < NY) && ( i < NX+1) && ( k == 0)) {
        // at this stage, yvort is in the tem2 array
        dum0 = data->tem2_4d_chunk;
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // use the v stagger macro to handle the
            // proper indexing
            TEM4D(i, j, 0, tidx) = TEM4D(i, j, 1, tidx);
            // Same note about ignoring upper boundary condition. 
        }
    }
}


/* Average our vorticity values back to the scalar grid for interpolation
   to the parcel paths. We're able to do this in parallel by making use of
   the three temporary arrays allocated on our grid, which means that the
   xvort/yvort/zvort arrays will be averaged into tem1/tem2/tem3. After
   calling this kernel, you MUST set the new pointers appropriately. */
__global__ void doVortAvg(datagrid *grid, integration_data *data, int tStart, int tEnd) {

    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;

    if ((i < NX) && (j < NY) && (k < NZ)) {
        // loop over the number of time steps we have in memory
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            // average the temporary arrays into the result arrays
            dum0 = data->tem1_4d_chunk;
            buf0 = data->xvort_4d_chunk;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            dum0 = data->tem2_4d_chunk;
            buf0 = data->yvort_4d_chunk;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            dum0 = data->tem3_4d_chunk;
            buf0 = data->zvort_4d_chunk;
            BUF4D(i, j, k, tidx) = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) +\
                                            TEM4D(i, j+1, k, tidx) + TEM4D(i+1, j+1, k, tidx) );
        }
    }
}

/* Average the derivatives within the temporary arrays used to compute
   the tilting rate and then combine the terms into the final zvtilt
   array. It is assumed that the derivatives have been precomputed into
   the temporary arrays. */
__global__ void doZVortTiltAvg(datagrid *grid, integration_data *data, int tStart, int tEnd) {
    // get our grid indices based on our block and thread info
    int i = blockIdx.x*blockDim.x + threadIdx.x;
    int j = blockIdx.y*blockDim.y + threadIdx.y;
    int k = blockIdx.z*blockDim.z + threadIdx.z;

    int NX = grid->NX;
    int NY = grid->NY;
    int NZ = grid->NZ;
    float *buf0, *dum0;
    float dwdx, dvdz, dwdy, dudz;

    // We do the average for each array at a given point
    // and then finish the computation for the zvort tilt
    if ((i < NX) && (j < NY) && (k < NZ)) {
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            dum0 = data->tem1_4d_chunk;
            dwdx = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) + \
                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            dum0 = data->tem2_4d_chunk;
            dvdz = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) + \
                            TEM4D(i, j, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            dum0 = data->tem3_4d_chunk;
            dwdy = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i, j+1, k, tidx) + \
                            TEM4D(i, k, k+1, tidx) + TEM4D(i, j+1, k+1, tidx) );

            dum0 = data->tem4_4d_chunk;
            dudz = 0.25 * ( TEM4D(i, j, k, tidx) + TEM4D(i+1, j, k, tidx) + \
                            TEM4D(i, j, k+1, tidx) + TEM4D(i+1, j, k+1, tidx) );

            buf0 = data->zvtilt_4d_chunk;
            BUF4D(i, j, k, tidx) = -1*(dwdx*dvdz - dwdy*dudz);
        }
    }
}


/*  Execute all of the required kernels on the GPU that are necessary for computing the 3
    components of vorticity. The idea here is that we're building wrappers on wrappers to
    simplify the process for the end user that just wants to calculate vorticity. This is
    also a necessary adjustment because the tendency calculations will require multiple
    steps, so transitioning this block of code as a proof of concept for how the programming
    model should work. */
void doCalcVort(datagrid *grid, integration_data *data, int tStart, int tEnd, dim3 numBlocks, dim3 threadsPerBlock) {
    // calculate the three compionents of vorticity
    calcvort<<<numBlocks, threadsPerBlock>>>(grid, data, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize() );
    gpuErrchk( cudaPeekAtLastError() );

    // apply the lower boundary condition to the horizontal
    // components of vorticity
    applyVortBC<<<numBlocks, threadsPerBlock>>>(grid, data, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize() );
    gpuErrchk( cudaPeekAtLastError() );

    // Average the vorticity to the scalar grid using the temporary
    // arrays we allocated. After doing the averaging, we have to 
    // set the pointers to the temporary arrays as the new xvort,
    // yvort, and zvort, and set the old x/y/zvort arrays as the new
    // temporary arrays. Note: may have to zero those out in the future...
    doVortAvg<<<numBlocks, threadsPerBlock>>>(grid, data, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize());
    gpuErrchk( cudaPeekAtLastError() );
} 

void doCalcVortTend(datagrid *grid, integration_data *data, int tStart, int tEnd, dim3 numBlocks, dim3 threadsPerBlock) {

    // Compute the vorticity tendency due to stretching. These conveniently
    // end up on the scalar grid, and no extra steps are required. This will
    // compute the tendency for all 3 components of vorticity. 
    calcvortstretch<<<numBlocks, threadsPerBlock>>>(grid, data, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize());
    gpuErrchk( cudaPeekAtLastError() );

    // Compute the vertical vorticity tendency due to tilting. We have to do 
    // each component individually because we have to average the arrays back
    // to the scalar grid. It's a mess. 
    calczvorttilt<<<numBlocks, threadsPerBlock>>>(grid, data, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize());
    gpuErrchk( cudaPeekAtLastError() );
    doZVortTiltAvg<<<numBlocks, threadsPerBlock>>>(grid, data, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize());
    gpuErrchk( cudaPeekAtLastError() );
}

__global__ void integrate(datagrid *grid, parcel_pos *parcels, integration_data *data, \
                          int tStart, int tEnd, int totTime, int direct) {

	int parcel_id = blockIdx.x;
    // safety check to make sure our thread index doesn't
    // go out of our array bounds
    if (parcel_id < parcels->nParcels) {
        bool is_ugrd = false;
        bool is_vgrd = false;
        bool is_wgrd = false;

        float pcl_u, pcl_v, pcl_w;
        float point[3];

        // loop over the number of time steps we are
        // integrating over
        for (int tidx = tStart; tidx < tEnd; ++tidx) {
            point[0] = parcels->xpos[PCL(tidx, parcel_id, totTime)];
            point[1] = parcels->ypos[PCL(tidx, parcel_id, totTime)];
            point[2] = parcels->zpos[PCL(tidx, parcel_id, totTime)];
            //printf("My Point Is: X = %f Y = %f Z = %f t = %d nParcels = %d\n", point[0], point[1], point[2], tidx, parcels->nParcels);

            is_ugrd = true;
            is_vgrd = false;
            is_wgrd = false;
            pcl_u = interp3D(grid, data->u_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);

            is_ugrd = false;
            is_vgrd = true;
            is_wgrd = false;
            pcl_v = interp3D(grid, data->v_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);

            is_ugrd = false;
            is_vgrd = false;
            is_wgrd = true;
            pcl_w = interp3D(grid, data->w_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            //printf("pcl u: %f pcl v: %f pcl w: %f\n", pcl_u, pcl_v, pcl_w);

            // interpolate scalar values to the parcel point
            is_ugrd = false;
            is_vgrd = false;
            is_wgrd = false;
            float pclxvort = interp3D(grid, data->xvort_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            float pclyvort = interp3D(grid, data->yvort_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            float pclzvort = interp3D(grid, data->zvort_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            float pclzvorttilt = interp3D(grid, data->zvtilt_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            float pclxvortstretch = interp3D(grid, data->xvstretch_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            float pclyvortstretch = interp3D(grid, data->yvstretch_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            float pclzvortstretch = interp3D(grid, data->zvstretch_4d_chunk, point, is_ugrd, is_vgrd, is_wgrd, tidx);
            
            // integrate X position forward by the U wind
            point[0] += pcl_u * (1.0f/6.0f) * direct;
            // integrate Y position forward by the V wind
            point[1] += pcl_v * (1.0f/6.0f) * direct;
            // integrate Z position forward by the W wind
            point[2] += pcl_w * (1.0f/6.0f) * direct;
            if ((pcl_u == -999.0) || (pcl_v == -999.0) || (pcl_w == -999.0)) {
                printf("Warning: missing values detected at x: %f y:%f z:%f with ground bounds X0: %f Y0: %f Z0: %f X1: %f Y1: %f Z1: %f\n", \
                    point[0], point[1], point[2], grid->xh[0], grid->yh[0], grid->zh[0], grid->xh[grid->NX-1], grid->yh[grid->NY-1], grid->zh[grid->NZ-1]);
                return;
            }


            parcels->xpos[PCL(tidx+1, parcel_id, totTime)] = point[0]; 
            parcels->ypos[PCL(tidx+1, parcel_id, totTime)] = point[1];
            parcels->zpos[PCL(tidx+1, parcel_id, totTime)] = point[2];
            parcels->pclu[PCL(tidx,   parcel_id, totTime)] = pcl_u;
            parcels->pclv[PCL(tidx,   parcel_id, totTime)] = pcl_v;
            parcels->pclw[PCL(tidx,   parcel_id, totTime)] = pcl_w;

            // Store the vorticity in the parcel
            parcels->pclxvort[PCL(tidx, parcel_id, totTime)] = pclxvort;
            parcels->pclyvort[PCL(tidx, parcel_id, totTime)] = pclyvort;
            parcels->pclzvort[PCL(tidx, parcel_id, totTime)] = pclzvort;
            parcels->pclzvorttilt[PCL(tidx, parcel_id, totTime)] = pclzvorttilt;
            parcels->pclxvortstretch[PCL(tidx, parcel_id, totTime)] = pclxvortstretch;
            parcels->pclyvortstretch[PCL(tidx, parcel_id, totTime)] = pclyvortstretch;
            parcels->pclzvortstretch[PCL(tidx, parcel_id, totTime)] = pclzvortstretch;
        }
    }
}

/*This function handles allocating memory on the GPU, transferring the CPU
arrays to GPU global memory, calling the integrate GPU kernel, and then
updating the position vectors with the new stuff*/
void cudaIntegrateParcels(datagrid *grid, integration_data *data, parcel_pos *parcels, int nT, int totTime, int direct) {

    int tStart, tEnd;
    tStart = 0;
    tEnd = nT;
    int NX, NY, NZ;
    // set the NX, NY, NZ
    // variables for calculations
    NX = grid->NX;
    NY = grid->NY;
    NZ = grid->NZ;


    // set the thread/block execution strategy for the kernels

    // Okay, so I think the last remaining issue might lie here. For some reason, some blocks 
    // must not be executing or something, seemingly related to the threadsPerBlock size. 
    // Changing to 4x4x4 fixed for xvort, but not yvort. I think we need to dynamically set
    // threadsPerBloc(x, y, z) based on the size of our grid at a given time step. 
    dim3 threadsPerBlock(8, 8, 8);
    dim3 numBlocks((int)ceil(NX/threadsPerBlock.x)+1, (int)ceil(NY/threadsPerBlock.y)+1, (int)ceil(NZ/threadsPerBlock.z)+1); 

    // we synchronize the device before doing anything to make sure all
    // array memory transfers have safely completed. This is probably 
    // unnecessary but I'm doing it anyways because overcaution never
    // goes wrong. Ever.
    gpuErrchk( cudaDeviceSynchronize() );
    gpuErrchk( cudaPeekAtLastError() );

    // Calculate the three compionents of vorticity
    // and do the necessary averaging. This is a wrapper that
    // calls the necessary kernels and assigns the pointers
    // appropriately such that the "user" only has to call this method.
    doCalcVort(grid, data, tStart, tEnd, numBlocks, threadsPerBlock);

    // Calculate the vorticity forcing terms for each of the 3 components.
    // This is a wrapper that calls the necessary kernels to compute the
    // derivatives and average them back to the scalar grid where necessary. 
    doCalcVortTend(grid, data, tStart, tEnd, numBlocks, threadsPerBlock);

    // Before integrating the trajectories, George Bryan sets some below-grid/surface conditions 
    // that we need to consider. This handles applying those boundary conditions. 
    applyMomentumBC<<<numBlocks, threadsPerBlock>>>(data->u_4d_chunk, data->v_4d_chunk, data->w_4d_chunk, NX, NY, NZ, tStart, tEnd);
    gpuErrchk(cudaDeviceSynchronize() );
    gpuErrchk( cudaPeekAtLastError() );

    // integrate the parcels forward in time and interpolate
    // calculations to trajectories. 
    integrate<<<parcels->nParcels, 1>>>(grid, parcels, data, tStart, tEnd, totTime, direct);
    gpuErrchk(cudaDeviceSynchronize() );
    gpuErrchk( cudaPeekAtLastError() );

}

#endif
