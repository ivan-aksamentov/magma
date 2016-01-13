/*
    -- MAGMA (version 2.0.0-beta2) --
       Univ. of Tennessee, Knoxville
       Univ. of California, Berkeley
       Univ. of Colorado, Denver
       @date January 2016

       @generated from sparse-iter/blas/magma_zdiagcheck.cu normal z -> d, Wed Jan  6 17:59:41 2016

*/
#include "common_magmasparse.h"

#define BLOCK_SIZE 256


// kernel
__global__ void 
zdiagcheck_kernel( 
    int num_rows, 
    int num_cols, 
    magmaDouble_ptr dval, 
    magmaIndex_ptr drowptr, 
    magmaIndex_ptr dcolind,
    magma_int_t * dinfo )
{
    int row = blockIdx.x*blockDim.x+threadIdx.x;
    int j;

    if(row<num_rows){
        int localinfo = 1;
        int start = drowptr[ row ];
        int end = drowptr[ row+1 ];
        // check whether there exists a nonzero diagonal entry
        for( j=start; j<end; j++){
            if( (dcolind[j] == row) && (dval[j] != MAGMA_D_ZERO) ){
                localinfo = 0;
            }
        }
        // set flag to 1
        if( localinfo == 1 ){
            dinfo[0] = -3009;
        }
    }
}



/**
    Purpose
    -------
    
    This routine checks for a CSR matrix whether there 
    exists a zero on the diagonal. This can be the diagonal entry missing
    or an explicit zero.
    
    Arguments
    ---------
                
    @param[in]
    dA          magma_d_matrix
                matrix in CSR format

    @param[in]
    queue       magma_queue_t
                Queue to execute in.

    @ingroup magmasparse_daux
    ********************************************************************/

extern "C" magma_int_t
magma_ddiagcheck(
    magma_d_matrix dA,
    magma_queue_t queue )
{
    magma_int_t info = 0;
    magma_int_t *hinfo = NULL;
    
    magma_int_t * dinfo = NULL;
    dim3 grid( magma_ceildiv( dA.num_rows, BLOCK_SIZE ) );
    magma_int_t threads = BLOCK_SIZE;
    
    CHECK( magma_imalloc( &dinfo, 1 ) );
    CHECK( magma_imalloc_cpu( &hinfo, 1 ) );
    hinfo[0] = 0;
    magma_isetvector( 1, hinfo, 1, dinfo, 1 );
    zdiagcheck_kernel<<< grid, threads, 0, queue->cuda_stream() >>>
    ( dA.num_rows, dA.num_cols, dA.dval, dA.drow, dA.dcol, dinfo );
    info = hinfo[0];
    magma_igetvector( 1, dinfo, 1, hinfo, 1 ); 
    info = hinfo[0];
    
cleanup:
    magma_free( dinfo );
    magma_free_cpu( hinfo );

    return info;
}