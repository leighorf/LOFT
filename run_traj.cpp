#include <iostream>
#include <fstream>
#include <string>
#include "mpi.h"
#include "readlofs.cpp"
#include "datastructs.cpp"
#include "integrate.h"

// I made this myself by stealing from LOFS
#define P2(t,p,mt) (((p)*(mt))+(t))
// stole this define from LOFS
#define P3(x,y,z,mx,my) (((z)*(mx)*(my))+((y)*(mx))+(x))
// I made this myself by stealing from LOFS
#define P4(x,y,z,t,mx,my,mz) ((t*mx*my*mz)+((z)*(mx)*(my))+((y)*(mx))+(x))
using namespace std;


/* Load the grid metadata and request a domain subset based on the 
 * current parcel positioning for the current time step. The idea is that 
 * for the first chunk of times read in (from 0 to N MPI ranks for time)
 * only the subset of the domain that matters for that period of time. 
 * When the next chunk of time is read in, check and see where the parcels
 * are currently and request a subset that is relevent to those parcels.   
 */
void loadMetadataAndGrid(string base_dir, datagrid *requested_grid, parcel_pos *parcels, int tstep) {

    // query the dataset structure
    lofs_get_dataset_structure(base_dir);
    // get the HDF metadata - return the first filename
    get_hdf_metadata(firstfilename,&nx,&ny,&nz,&nodex,&nodey);

    datagrid temp_grid;

    // for right now, set the grid bounds to the saved
    // bounds for testing purposes
    temp_grid.X0 = saved_X0; temp_grid.Y0 = saved_Y0;
    temp_grid.X1 = saved_X1; temp_grid.Y1 = saved_Y1;
    temp_grid.Z0 = 0; temp_grid.Z1 = nz-1; // nz comes from readlofs

    // request the full grid so that we can find the indices
    // of where our parcels are, and then request a smaller
    // subset from there.
    lofs_get_grid(&temp_grid);

    // find the min/max index bounds of 
    // our parcels
    float point[3];
    int idx_4D[4];
    int min_i = temp_grid.NX+1;
    int min_j = temp_grid.NY+1;
    int min_k = temp_grid.NZ+1;
    int max_i = -1;
    int max_j = -1;
    int max_k = -1;
    for (int pcl = 0; pcl < parcels->nParcels; ++pcl) {
        point[0] = parcels->xpos[P2(tstep, pcl, parcels->nTimes)];
        point[1] = parcels->ypos[P2(tstep, pcl, parcels->nTimes)];
        point[2] = parcels->zpos[P2(tstep, pcl, parcels->nTimes)];
        // find the nearest grid point!
        _nearest_grid_idx(point, temp_grid.xh, temp_grid.yh, temp_grid.zh, idx_4D, temp_grid.NX, temp_grid.NY, temp_grid.NZ);
        if ( (idx_4D[0] == -1) || (idx_4D[1] == -1) || (idx_4D[2] == -1) ) {
            cout << "INVALID POINT X " << point[0] << " Y " << point[1] << " Z " << point[2] << endl;
            cout << "Parcel X " << parcels->xpos[P2(tstep, pcl, parcels->nTimes)];
            cout << " Parcel Y " << parcels->ypos[P2(tstep, pcl, parcels->nTimes)];
            cout << " Parcel Z " << parcels->zpos[P2(tstep, pcl, parcels->nTimes)] << endl;
            cout << tstep << " " << pcl << " " << parcels->nTimes << endl;
        }
        // check to see if we've found the min/max
        // for the dimension
        if (idx_4D[0] < min_i) min_i = idx_4D[0]; 
        if (idx_4D[0] > max_i) max_i = idx_4D[0]; 
        if (idx_4D[1] < min_j) min_j = idx_4D[1]; 
        if (idx_4D[1] > max_j) max_j = idx_4D[1]; 
        if (idx_4D[2] < min_k) min_k = idx_4D[2]; 
        if (idx_4D[2] > max_k) max_k = idx_4D[2]; 
        //cout << "min i " << min_i << " max i " << max_i << endl;
        //cout << "min j " << min_j << " max i " << max_j << endl;
        //cout << "min k " << min_k << " max i " << max_k << endl;
    }

    // we want to add a buffer to our dimensions so that
    // the parcels don't accidentally move outside of our
    // requested data. If the buffer goes outside the 
    // saved dimensions, set it to the saved dimensions
    min_i = saved_X0 + min_i - 20;
    max_i = saved_X0 + max_i + 20;
    min_j = saved_Y0 + min_j - 20;
    max_j = saved_Y0 + max_j + 20;
    min_k = min_k - 20;
    max_k = max_k + 20;
    cout << "Attempted Parcel Bounds In Grid" << endl;
    cout << "X0: " << min_i << " X1: " << max_i << endl;
    cout << "Y0: " << min_j << " Y1: " << max_j << endl;
    cout << "Z0: " << min_k << " Z1: " << max_k << endl;

    // keep the data in our saved bounds
    if (min_i < saved_X0) min_i = saved_X0;
    if (max_i > saved_X1) max_i = saved_X1;
    if (min_j < saved_Y0) min_j = saved_Y0;
    if (max_j > saved_Y1) max_j = saved_Y1;
    if (min_k < 0) min_k = 0;
    if (max_k > nz-1) max_k = nz-1;



    cout << "Parcel Bounds In Grid" << endl;
    cout << "X0: " << min_i << " X1: " << max_i << endl;
    cout << "Y0: " << min_j << " Y1: " << max_j << endl;
    cout << "Z0: " << min_k << " Z1: " << max_k << endl;


    requested_grid->X0 = min_i; requested_grid->Y0 = min_j;
    requested_grid->X1 = max_i; requested_grid->Y1 = max_j;
    requested_grid->Z0 = min_k; requested_grid->Z1 = max_k;

    // request our grid subset now
    cout << "REQUESTING METADATA & GRID" << endl;
    lofs_get_grid(requested_grid);
    cout << "END METADATA & GRID REQUEST" << endl;
    // clear the memory from the temp grid
    delete[] temp_grid.xh;
    delete[] temp_grid.yh;
    delete[] temp_grid.zh;
    delete[] temp_grid.xf;
    delete[] temp_grid.yf;
    delete[] temp_grid.zf;
}

/* Read in the U, V, and W vector components from the disk, provided previously allocated memory buffers
 * and the time requested in the dataset. 
 */
void loadVectorsFromDisk(datagrid *requested_grid, float *ubuffer, float *vbuffer, float *wbuffer, double t0) {
    // request 3D field!
    lofs_read_3dvar(requested_grid, ubuffer, (char *)"u", t0);
    lofs_read_3dvar(requested_grid, vbuffer, (char *)"v", t0);
    lofs_read_3dvar(requested_grid, wbuffer, (char *)"w", t0);
}


/* Seed some parcels into the domain
 * in physical gridpoint space, and then
 * fill the remainder of the parcel traces
 * with missing values. 
 */
void seed_parcels(parcel_pos *parcels, int nTotTimes) {
    // place a cube of parcels in the domain between xstart, 
    // xend, ystart, yend, zstart, and zend in spacing
    // increments dx, dy, dz
    float xstart = -6015; float xend = -3015; float dx = 30;
    float ystart = -4215; float yend = -3045; float dy = 30;
    float zstart = 30; float zend = 530; float dz = 30;
    // the number of parcels we will be seeding
    // - note I kind of made this by trial and error. 
    // It may be subject to seg faults?
    int pnx = (int) ceil((xend - xstart) / dx);
    int pny = (int) ceil((yend - ystart) / dy);
    int pnz = (int) ceil((zend - zstart) / dz);
    int nParcels = pnx*pny*pnz;

    // allocate memory for the parcels
    // we are integrating for the entirety 
    // of the simulation.
    parcels->xpos = new float[nParcels * nTotTimes];
    parcels->ypos = new float[nParcels * nTotTimes];
    parcels->zpos = new float[nParcels * nTotTimes];
    parcels->nParcels = nParcels;
    parcels->nTimes = nTotTimes;

    int pid = 0;
    for (float i = xstart; i < xend; i+=dx) {
        for (float j = ystart; j < yend; j+=dy) {
            for (float k = zstart; k < zend; k += dz) {
                parcels->xpos[P2(0, pid, parcels->nTimes)] = i;
                parcels->ypos[P2(0, pid, parcels->nTimes)] = j;
                parcels->zpos[P2(0, pid, parcels->nTimes)] = k;
                pid += 1;
            }
        }
    }

    // fill the remaining portions of the array
    // with the missing value flag for the future
    // times that we haven't integrated to yet.
    cout <<  parcels->zpos[P2(0, 29, parcels->nTimes)] << endl;
    for (int p = 0; p < nParcels; ++p) {
        for (int t = 1; t < parcels->nTimes; ++t) {
            parcels->xpos[P2(t, p, parcels->nTimes)] = -99999.0;
            parcels->ypos[P2(t, p, parcels->nTimes)] = -99999.0;
            parcels->zpos[P2(t, p, parcels->nTimes)] = -99999.0;
        }
    }
    cout << "END PARCEL SEED" << endl;

}


/* Write out the parcel arrays to a 
 * CSV file format on the disk.
 */
void write_data(parcel_pos parcels, float *uparcels, float *vparcels, float *wparcels) {
    cout << "WRITING DATA" << endl;
    ofstream outfile;
    outfile.open("./result.csv");
    int nParcels = parcels.nParcels;
    int nT = parcels.nTimes;
    
    // loop over each parcel
    float max_u, max_v, max_w;
    max_u = -1; max_v = -1; max_w = -1;
    for (int pcl = 0; pcl < nParcels; ++pcl) {
        // print the parcel start flag 
        outfile << "!Parcel " << pcl << endl; 
        // loop over the times
        for (int t = 0; t < nT; ++t) {
            // for each row: x position, y position, z position
                outfile << parcels.xpos[P2(t, pcl, nT)] << ", ";
                outfile << parcels.ypos[P2(t, pcl, nT)] << ", ";
                outfile << parcels.zpos[P2(t, pcl, nT)] << ", ";
                if (t == nT-1) {
                    outfile << -999.0 << ", ";
                    outfile << -999.0 << ", ";
                    outfile << -999.0 << endl;
                }
                else {
                    outfile << uparcels[P2(t, pcl, nT)] << ", ";
                    outfile << vparcels[P2(t, pcl, nT)] << ", ";
                    outfile << wparcels[P2(t, pcl, nT)] << endl;
                }
        }
        // parcel end flag
        outfile << "!End " << pcl << endl;
    }
}


/* This is the main program that does the parcel trajectory analysis.
 * It first sets up the parcel vectors and seeds the starting locations.
 * It then loads a chunk of times into memory by calling the LOFS api
 * wrappers, with the number of times read in being determined by the
 * number of MPI ranks launched. It then passes the vectors and the 4D u/v/w 
 * data chunks to the GPU, and then proceeds with another time chunk.
 */
int main(int argc, char **argv ) {
    string base_dir = "/u/sciteam/halbert/project_bagm/khalbert/30m-every-time-step/3D";
    int rank, size;
    long N, MX, MY, MZ;
    int nTimeChunks = 8;

    // initialize a bunch of MPI stuff.
    // Rank tells you which process
    // you are and size tells y ou how
    // many processes there are total
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Errhandler_set(MPI_COMM_WORLD,MPI_ERRORS_ARE_FATAL); /* return info about
                                                                   errors */
    MPI_Barrier(MPI_COMM_WORLD);

    // the number of time steps we have is 
    // the number of MPI ranks there are
    // times the number of integration time chunks,
    // plus the very last integration end time
    int nTotTimes = (size*nTimeChunks)+1;

    // we're gonna make a test by creating a horizontal
    // and zonal line of parcels
    parcel_pos parcels;
    datagrid requested_grid;
    float *uparcels;
    float *vparcels;
    float *wparcels;


    for (int tChunk = 0; tChunk < nTimeChunks; ++tChunk) {
        // if this is the first chunk of time, seed the
        // parcel start locations
        cout << "SEEDING PARCELS" << endl;
        if (tChunk == 0) {
            seed_parcels(&parcels, nTotTimes);
        }

        // read in the metadata - later we will make
        // the requested grid dynamic based on the
        // parcel seeds
        loadMetadataAndGrid(base_dir, &requested_grid, &parcels, tChunk*size); 


        // the number of grid points requested
        N = (requested_grid.NX)*(requested_grid.NY)*(requested_grid.NZ);


        // get the size of the domain we will
        // be requesting. The +1 is safety for
        // staggered grids
        MX = (long) (requested_grid.NX);
        MY = (long) (requested_grid.NY);
        MZ = (long) (requested_grid.NZ);

        // allocate space for U, V, and W arrays
        long bufsize = (long) (requested_grid.NX+1) * (long) (requested_grid.NY+1) * (long) (requested_grid.NZ+1) * (long) sizeof(float);
        float *ubuf, *vbuf, *wbuf;
        ubuf = (float *) malloc ((size_t)bufsize);
        vbuf = (float *) malloc ((size_t)bufsize);
        wbuf = (float *) malloc ((size_t)bufsize);
        /*
        float *ubuf = new float[N];
        float *vbuf = new float[N];
        float *wbuf = new float[N];
        */

        // construct a 4D contiguous array to store stuff in.
        // bufsize is the size of the 3D component and size is
        // the number of MPI ranks (which is also the number of times)
        // read in
        float *u_time_chunk, *v_time_chunk, *w_time_chunk; 
        if (rank == 0) {
            u_time_chunk = (float *) malloc ((size_t)bufsize*size);
            v_time_chunk = (float *) malloc ((size_t)bufsize*size);
            w_time_chunk = (float *) malloc ((size_t)bufsize*size);

            uparcels = new float[parcels.nParcels * nTotTimes];
            vparcels = new float[parcels.nParcels * nTotTimes];
            wparcels = new float[parcels.nParcels * nTotTimes];
        }
        /*
        float *u_time_chunk = new float[N*size];
        float *v_time_chunk = new float[N*size];
        float *w_time_chunk = new float[N*size];
        */

        printf("TIMESTEP %d/%d %d %f\n", rank, size, rank + tChunk*size, alltimes[12000 + rank + tChunk*size]);
        // load u, v, and w into memory
        loadVectorsFromDisk(&requested_grid, ubuf, vbuf, wbuf, alltimes[12000 + rank + tChunk*size]);
        
        int senderr_u = MPI_Gather(ubuf, N, MPI_FLOAT, u_time_chunk, N, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_v = MPI_Gather(vbuf, N, MPI_FLOAT, v_time_chunk, N, MPI_FLOAT, 0, MPI_COMM_WORLD);
        int senderr_w = MPI_Gather(wbuf, N, MPI_FLOAT, w_time_chunk, N, MPI_FLOAT, 0, MPI_COMM_WORLD);

        if (rank != 0) {
            delete[] requested_grid.xf;
            delete[] requested_grid.yf;
            delete[] requested_grid.zf;

            delete[] requested_grid.xh;
            delete[] requested_grid.yh;
            delete[] requested_grid.zh;

            delete[] ubuf;
            delete[] vbuf;
            delete[] wbuf;
        }

        if (rank == 0) {
            // send to the GPU
            // comment out if you're running on XE node
            int nParcels = parcels.nParcels;
            cudaIntegrateParcels(requested_grid, parcels, u_time_chunk, v_time_chunk, w_time_chunk, uparcels, vparcels, wparcels, MX, MY, MZ, size, tChunk, nTotTimes); 


            // communicate the data to the other ranks
            for (int r = 1; r < size; ++r) {
                MPI_Send(parcels.xpos, nParcels*nTotTimes, MPI_FLOAT, r, 0, MPI_COMM_WORLD);
                MPI_Send(parcels.ypos, nParcels*nTotTimes, MPI_FLOAT, r, 1, MPI_COMM_WORLD);
                MPI_Send(parcels.zpos, nParcels*nTotTimes, MPI_FLOAT, r, 2, MPI_COMM_WORLD);
            }
            
            // if the last integration has been performed, write the data to disk
            if (tChunk == nTimeChunks-1) {
                write_data(parcels, uparcels, vparcels, wparcels);
            }
        }

        else {
            MPI_Status status;
            MPI_Recv(parcels.xpos, parcels.nParcels*nTotTimes, MPI_FLOAT, 0, 0, MPI_COMM_WORLD, &status);
            MPI_Recv(parcels.ypos, parcels.nParcels*nTotTimes, MPI_FLOAT, 0, 1, MPI_COMM_WORLD, &status);
            MPI_Recv(parcels.zpos, parcels.nParcels*nTotTimes, MPI_FLOAT, 0, 2, MPI_COMM_WORLD, &status);
        }
    }

    MPI_Finalize();
}
