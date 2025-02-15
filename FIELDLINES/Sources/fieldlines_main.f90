!-----------------------------------------------------------------------
!     Program:       FIELDLINES
!     Authors:       S. Lazerson
!     Date:          02/21/2012
!     Description:   The FIELDLINES code is a versatile fieldlines
!                    tracing package for MHD Equilibria.  In general,
!                    the code follows fieldlines on an R,phi,Z grid
!                    similar to an mgrid file.  It's main function is
!                    to produce Poincare plots but it can also be used
!                    to visualize the 3D trajectories of fieldlines.
!     References:
!-----------------------------------------------------------------------
      PROGRAM FIELDLINES
!-----------------------------------------------------------------------
!     Libraries
!-----------------------------------------------------------------------
      USE fieldlines_runtime
      USE wall_mod, ONLY: wall_free
      USE fieldlines_grid
      USE fieldlines_lines, ONLY: R_lines, Z_lines, PHI_lines, &
                                  Rhc_lines, Zhc_lines, B_lines
      USE EZspline_obj
      USE EZspline
      USE mpi_sharmem
      USE mpi_params
      USE mpi_inc
#if defined(LHDF5)
    USE hdf5
#endif
!-----------------------------------------------------------------------
!     Local Variables
!          numargs      Number of input arguments
!          i            Index
!          arg_len      Length of input strings
!          arg1         Input file
!          args         Input arguments
!-----------------------------------------------------------------------
      IMPLICIT NONE
      integer                                      :: numargs,i,ier, vmajor, vminor, liblen, nshar
      integer                                      :: h5major, h5minor, h5rel, h5par
      integer, parameter                           :: arg_len =256
      character(LEN=MPI_MAX_LIBRARY_VERSION_STRING) :: mpi_lib_name
      character*(arg_len)                          :: arg1
      character*(arg_len),allocatable,dimension(:) :: args

#if defined(GIT_VERSION_EXT)
      CHARACTER(64), PARAMETER :: git_repository = GIT_REPO_EXT
      CHARACTER(32), PARAMETER :: git_version = GIT_VERSION_EXT
      CHARACTER(40), PARAMETER :: git_hash = GIT_HASH_EXT
      CHARACTER(32), PARAMETER :: git_branch = GIT_BRANCH_EXT
      CHARACTER(19), PARAMETER :: built_on = BUILT_ON_EXT
#else
      CHARACTER(64), PARAMETER :: git_repository = "not from a git repo"
      CHARACTER(32), PARAMETER :: git_version = ""
      CHARACTER(40), PARAMETER :: git_hash = ""
      CHARACTER(32), PARAMETER :: git_branch = ""
      CHARACTER(19), PARAMETER :: built_on = ""
#endif
!-----------------------------------------------------------------------
!     Begin Program
!-----------------------------------------------------------------------
      
      myworkid = master
      ierr_mpi = MPI_SUCCESS
#if defined(MPI_OPT)
      CALL MPI_INIT(ierr_mpi) ! MPI
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_INIT_ERR, 'fieldlines_main:init', ierr_mpi)
      CALL MPI_COMM_DUP( MPI_COMM_WORLD, MPI_COMM_FIELDLINES, ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_RANK_ERR, 'fieldlines_main:rank', ierr_mpi)
      CALL MPI_COMM_RANK( MPI_COMM_FIELDLINES, myworkid, ierr_mpi )              ! MPI
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_RANK_ERR, 'fieldlines_main:rank2', ierr_mpi)
      CALL MPI_COMM_SIZE( MPI_COMM_FIELDLINES, nprocs_fieldlines, ierr_mpi )          ! MPI
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_SIZE_ERR, 'fieldlines_main:size', ierr_mpi)
      CALL MPI_COMM_SPLIT_TYPE(MPI_COMM_FIELDLINES, MPI_COMM_TYPE_SHARED, 0, MPI_INFO_NULL, MPI_COMM_SHARMEM, ierr_mpi)
      CALL MPI_COMM_RANK(MPI_COMM_SHARMEM, myid_sharmem, ierr_mpi)
      CALL MPI_COMM_SIZE(MPI_COMM_SHARMEM, nshar, ierr_mpi) ! MPI
      CALL MPI_GET_VERSION(vmajor,vminor,ier)
      CALL MPI_GET_LIBRARY_VERSION(mpi_lib_name,liblen,ier)
      CALL MPI_ERRHANDLER_SET(MPI_COMM_WORLD,MPI_ERRORS_RETURN,ierr_mpi)
#endif

#if defined(LHDF5)
    CALL H5GET_LIBVERSION_F(h5major, h5minor, h5rel, ier)
    h5par = 0
#endif

#if defined(HDF5_PAR)
    h5par = 1
#endif

      ! Intialize variables
      CALL fieldlines_init_vars


      IF (myworkid == master) THEN
         !OPEN(6,CARRIAGECONTROL='fortran')
         !OPEN(6, RECL = 2**24)
         lverb = .true.
         numargs=0
         i=0
         arg1=''
         
         ! First Handle the input arguments
         CALL GETCARG(1, arg1, numargs)
         ALLOCATE(args(numargs))
         ! Cycle through Arguments
         i=1
         DO WHILE (i <= numargs)
            call GETCARG(i,args(i),numargs)
            select case (args(i))
               case ("-noverb")  ! No Verbose Output
                   lverb=.false.
               case ("-vac")     ! Vacuum Fields Only
                   lvac=.true.
               case ("-pres")    ! Calculate and output pressure 
                   lpres=.true.
               case ("-plasma") ! Plasma Region only
                   lplasma_only = .true.
               case ("-axis")
                   laxis_i  = .true.
               case ("-auto")
                   lauto  = .true.
               case ("-edge","-edge_start")
                   ledge_start  = .true.
               case ("-field")
                   lbfield_only  = .true.
               case ("-vecpot")
                   lafield_only  = .true.
               case ("-hitonly","-hit_only")
                   lhitonly  = .true.
               case ("-reverse")
                   lreverse = .true.
               case ("-modb")
                   lmodb = .true.
               case ("-raw")
                   lraw = .true.
               case ("-emc3")
                   lemc3 = .true.
               case ("-vmec")
                   i = i + 1
                   lvmec = .true.
                   CALL GETCARG(i,id_string,numargs)
                case ("-eqdsk")
                    i = i + 1
                    leqdsk = .true.
                    CALL GETCARG(i, id_string, numargs)
                    i = i + 1
                    CALL GETCARG(i, eqdsk_string, numargs)
               case ("-pies")
                   i = i + 1
                   lpies = .true.
                   CALL GETCARG(i,id_string,numargs)
               case ("-spec")
                   i = i + 1
                   lspec = .true.
                   CALL GETCARG(i,id_string,numargs)
               case ("-hint")
                   i = i + 1
                   lhint = .true.
                   CALL GETCARG(i,id_string,numargs)
               case ("-mgrid")
                   i = i + 1
                   lmgrid = .true.
                   CALL GETCARG(i,mgrid_string,numargs)

               case ("-coil","-coils")
                   i = i + 1
                   lcoil  = .true.
                   CALL GETCARG(i,coil_string,numargs)
               case ("-nescoil")
                   i = i + 1
                   lnescoil = .true.
                   CALL GETCARG(i,nescoil_string,numargs)
               case ("-restart")
                   i = i + 1
                   lrestart = .true.
                   CALL GETCARG(i,restart_string,numargs)
               case ("-vessel")
                   i = i + 1
                   lvessel  = .true.
                   CALL GETCARG(i,vessel_string,numargs)
               case ("-screen")
                   i = i + 1
                   lvessel  = .true.
                   lwall_trans = .true.
                   CALL GETCARG(i,vessel_string,numargs)
               case ("-full")
                   nruntype = runtype_full
                   lauto = .true.
               case ("-gridgen")
                   nruntype = runtype_gridgen
                   lauto = .true.
               case ("-backflow")
                   nruntype = runtype_backflow
               case ("-field_start")
                   lfield_start = .true.
                   i = i + 1
                   CALL GETCARG(i,restart_string,numargs)
                   i = i + 1
                   CALL GETCARG(i,args(i),numargs)
                   READ(args(i),*,IOSTAT=ier) line_select
               case ("-help","-h") ! Output Help message
                  WRITE(6,'(a,f5.2)') 'FIELDLINES Version ',FIELDLINES_VERSION
                  write(6,*)' Fieldline Tracing Code'
                  write(6,*)' Usage: xfieldlines <options>'
                  write(6,*)'    <options>'
                  write(6,*)'     -vmec ext:     VMEC input/wout extension'
                  write(6,*)'     -vmec ext:     HINT input/magslice extension'
                  write(6,*) '    -eqdsk in gf   Fieldlines input file and gfile'
                  !write(6,*)'     -pies ext:   PIES input extension (must have &INDATA namelist)'
                  !write(6,*)'     -spec ext:     SPEC input extension (must have &INDATA namelist)'
                  write(6,*)'     -vessel file:  Vessel File (for limiting)'
                  write(6,*)'     -screen file:  Vessel File (FSM diagnostic)'
                  write(6,*)'     -mgrid file:   MAKEGRID File (for vacuum)'
                  write(6,*)'     -coil file:    Coils. File (for vacuum)'
                  write(6,*)'     -nescoil file: NESCOIL File (for vacuum)'
                  !write(6,*)'     -restart ext:  FIELDLINES HDF5 extension.'
                  write(6,*)'     -field_start file line:  Restart from a field line.'
                  write(6,*)'     -axis          Coil on mag_axis with curtor'
                  write(6,*)'     -full          Full Auto calculation'
                  write(6,*)'     -gridgen       Grid generation type run'
                  write(6,*)'     -vac           Only vacuum field'
                  write(6,*)'     -plasma        Only Plasma field (in equilibrium)'
                  write(6,*)'     -reverse       Follow field backwards'
                  write(6,*)'     -backflow      Follow wall hits in reverse'
                  write(6,*)'     -auto          Auto calculate starting points'
                  write(6,*)'     -edge          Auto calculate starting points (from VMEC edge)'
                  write(6,*)'     -field         Output B-Field on Grid (no fieldlines)'
                  write(6,*)'     -modb          Saves |B| along field line trace'
                  write(6,*)'     -vecpot        Output Vector Potential on Grid (no fieldlines)'
                  write(6,*)'     -noverb        Supress all screen output'
                  write(6,*)'     -help          Output help message'
#if defined(MPI_OPT)
                  CALL MPI_FINALIZE(ierr_mpi)   
                  IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_FINE_ERR,'fieldlines_main:fine',ierr_mpi)
#endif
            end select
            i = i + 1
         END DO
         DEALLOCATE(args)
         WRITE(6,'(a,f5.2)') 'FIELDLINES Version ',FIELDLINES_VERSION
#if defined(LHDF5)
         IF (h5par > 0) THEN
            WRITE(6,'(A)')      '-----  HDF5 (Parallel) Parameters  -----'
         ELSE
            WRITE(6,'(A)')      '-----  HDF5 Parameters  -----'
         ENDIF
         WRITE(6,'(A,I2,2(A,I2.2))')  '   HDF5_version:  ', h5major,'.',h5minor,' release: ',h5rel
#endif
         WRITE(6,'(A)')      '-----  MPI Parameters  -----'
         WRITE(6,'(A,I2,A,I2.2)')  '   MPI_version:  ', vmajor,'.',vminor
         WRITE(6,'(A,A)')  '   ', TRIM(mpi_lib_name(1:liblen))
         WRITE(6,'(A,I8)')  '   Nproc_total:  ', nprocs_fieldlines
         WRITE(6,'(A,3X,I5)')  '   Nproc_shared: ', nshar
         WRITE(6,'(A)')      '-----  GIT Repository  -----'
         WRITE(6,'(A,A)')  '   Repository: ', TRIM(git_repository)
         WRITE(6,'(A,A)')  '   Branch:     ', TRIM(git_branch)
         WRITE(6,'(A,A)')  '   Version:    ', TRIM(git_version)
         WRITE(6,'(A,A)')  '   Built-on:   ', TRIM(built_on)
         WRITE(6,'(A,A)')  '   Hash:       ', TRIM(git_hash)
      END IF
      CALL FLUSH(6)
      id_string = TRIM(id_string)
      id_string = ADJUSTL(id_string)
      mgrid_string = TRIM(mgrid_string)
      mgrid_string = ADJUSTL(mgrid_string)
      eqdsk_string = TRIM(eqdsk_string)
      eqdsk_string = ADJUSTL(eqdsk_string)
      restart_string = TRIM(restart_string)
      restart_string = ADJUSTL(restart_string)
      coil_string = TRIM(coil_string)
      coil_string = ADJUSTL(coil_string)
      vessel_string = TRIM(vessel_string)
      vessel_string = ADJUSTL(vessel_string)
      ! Broadcast variables
#if defined(MPI_OPT)
      CALL MPI_BARRIER(MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BARRIER_ERR,'fieldlines_main:barrier',ierr_mpi)
      CALL MPI_BCAST(id_string,256,MPI_CHARACTER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'fieldlines_main:id_string',ierr_mpi)
      CALL MPI_BCAST(mgrid_string,256,MPI_CHARACTER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'fieldlines_main:mgrid_string',ierr_mpi)
      CALL MPI_BCAST(eqdsk_string, 256, MPI_CHARACTER, master, MPI_COMM_FIELDLINES, ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR, 'eqdsk_string', ierr_mpi)
      CALL MPI_BCAST(coil_string,256,MPI_CHARACTER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'coil_string',ierr_mpi)
      CALL MPI_BCAST(vessel_string,256,MPI_CHARACTER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'vessel_string',ierr_mpi)
      CALL MPI_BCAST(restart_string,256,MPI_CHARACTER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'restart_string',ierr_mpi)
      CALL MPI_BCAST(lvmec,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lvmec',ierr_mpi)
      CALL MPI_BCAST(leqdsk, 1, MPI_LOGICAL, master, MPI_COMM_FIELDLINES, ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR, 'leqdsk', ierr_mpi)
      CALL MPI_BCAST(lhint,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lhint',ierr_mpi)
      CALL MPI_BCAST(lhitonly,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lhitonly',ierr_mpi)
      CALL MPI_BCAST(lpies,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lpies',ierr_mpi)
      CALL MPI_BCAST(lplasma_only,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lplasma_only',ierr_mpi)
      CALL MPI_BCAST(lspec,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lspec',ierr_mpi)
      CALL MPI_BCAST(lmgrid,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lmgrid',ierr_mpi)
      CALL MPI_BCAST(lcoil,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lcoil',ierr_mpi)
      CALL MPI_BCAST(lvessel,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lvessel',ierr_mpi)
      CALL MPI_BCAST(lvac,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lvac',ierr_mpi)
      CALL MPI_BCAST(lpres,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lpres',ierr_mpi)
      CALL MPI_BCAST(laxis_i,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'laxis_i',ierr_mpi)
      CALL MPI_BCAST(lmu,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lmu',ierr_mpi)
      CALL MPI_BCAST(lrestart,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lrestart',ierr_mpi)
      CALL MPI_BCAST(ladvanced,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'ladvanced',ierr_mpi)
      CALL MPI_BCAST(lauto,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lauto',ierr_mpi)
      CALL MPI_BCAST(lbfield_only,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lbfield_only',ierr_mpi)
      CALL MPI_BCAST(lraw,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lraw',ierr_mpi)
      CALL MPI_BCAST(lafield_only,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lafield_only',ierr_mpi)
      CALL MPI_BCAST(lreverse,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lreverse',ierr_mpi)
      CALL MPI_BCAST(lnescoil,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lnescoil',ierr_mpi)
      CALL MPI_BCAST(lemc3,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lemc3',ierr_mpi)
      CALL MPI_BCAST(lerror_field,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lerror',ierr_mpi)
      CALL MPI_BCAST(lwall_trans,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lwall_trans',ierr_mpi)
      CALL MPI_BCAST(ledge_start,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'ledge_start',ierr_mpi)
      CALL MPI_BCAST(lmodb,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lmodb',ierr_mpi)
      CALL MPI_BCAST(lfield_start,1,MPI_LOGICAL, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'lfield_start',ierr_mpi)
      CALL MPI_BCAST(line_select,1,MPI_INTEGER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'line_select',ierr_mpi)
      CALL MPI_BCAST(nruntype,1,MPI_INTEGER, master, MPI_COMM_FIELDLINES,ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BCAST_ERR,'nruntype',ierr_mpi)
#endif
      ! Handle different run type
      CALL fieldlines_init
      IF (lemc3 .or. lbfield_only .or. lafield_only) nruntype=runtype_norun
      SELECT CASE(nruntype)
         CASE(runtype_old)
            CALL fieldlines_follow
         CASE(runtype_full)
            IF (lverb) WRITE(6,'(A)') '===========ROUGH GRID=========='
            IF (lverb) WRITE(6,'(A,F8.5,A,F8.5,A)') '   EDGE_INNER[R,Z]   = [',&
                     r_start(1),',',z_start(1),']'
            IF (lverb) WRITE(6,'(A,F8.5,A,F8.5,A)') '   EDGE_OUTER[R,Z]   = [',&
                     MAXVAL(r_start,MASK = r_start > 0),',',MAXVAL(z_start,MASK = r_start > 0),']'
#if defined(MPI_OPT)
            CALL MPI_BARRIER(MPI_COMM_FIELDLINES,ierr_mpi)
            IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BARRIER_ERR,'fieldlines_init:rough_follow',ierr_mpi)
#endif
            CALL fieldlines_follow  ! This call on field grid
#if defined(MPI_OPT)
            CALL MPI_BARRIER(MPI_COMM_FIELDLINES,ierr_mpi)
            IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_BARRIER_ERR,'fieldlines_init:follow',ierr_mpi)
#endif
            CALL fieldlines_init_subgrid
            CALL fieldlines_follow  ! This call on subgrid grid
            !CALL fieldlines_periodic_orbits  ! This call on subgrid grid
            !IF (lverb) CALL fieldlines_calc_surface_fit(25)
         CASE(runtype_backflow)
            IF (lverb) WRITE(6,'(A)') '===========Wall Hits=========='
            CALL fieldlines_follow
            CALL fieldlines_init_backflow
         CASE(runtype_gridgen)
            IF (lverb) WRITE(6,'(A)') '===========Grid Generation=========='
            CALL fieldlines_gridgen
         CASE(runtype_norun)
      END SELECT
      ! Output Date
      CALL fieldlines_write
      

      ! Clean up
      IF (lvessel) CALL wall_free(ier, MPI_COMM_FIELDLINES)
      IF (ASSOCIATED(raxis)) CALL mpidealloc(raxis,win_raxis)
      IF (ASSOCIATED(phiaxis)) CALL mpidealloc(phiaxis,win_phiaxis)
      IF (ASSOCIATED(zaxis)) CALL mpidealloc(zaxis,win_zaxis)
      IF (ASSOCIATED(B_R)) CALL mpidealloc(B_R,win_B_R)
      IF (ASSOCIATED(B_PHI)) CALL mpidealloc(B_PHI,win_B_PHI)
      IF (ASSOCIATED(B_Z)) CALL mpidealloc(B_Z,win_B_Z)
      IF (ASSOCIATED(PRES_G).and.lpres) CALL mpidealloc(PRES_G,win_PRES)
      IF (ASSOCIATED(BR4D)) CALL mpidealloc(BR4D,win_BR4D)
      IF (ASSOCIATED(BZ4D)) CALL mpidealloc(BZ4D,win_BZ4D)
      IF (ASSOCIATED(MU4D)) CALL mpidealloc(MU4D,win_MU4D)
      IF (ASSOCIATED(MODB4D)) CALL mpidealloc(MODB4D,win_MODB4D)
      IF (ALLOCATED(R_lines)) DEALLOCATE(R_lines)
      IF (ALLOCATED(Z_lines)) DEALLOCATE(Z_lines)
      IF (ALLOCATED(PHI_lines)) DEALLOCATE(PHI_lines)
      IF (ALLOCATED(Rhc_lines)) DEALLOCATE(Rhc_lines)
      IF (ALLOCATED(Zhc_lines)) DEALLOCATE(Zhc_lines)
      IF (ALLOCATED(B_lines)) DEALLOCATE(B_lines)
      IF (EZspline_allocated(BR_spl)) CALL EZspline_free(BR_spl,ier)
      IF (EZspline_allocated(BZ_spl)) CALL EZspline_free(BZ_spl,ier)
      IF (EZspline_allocated(MU_spl)) CALL EZspline_free(MU_spl,ier)
      IF (EZspline_allocated(MODB_spl)) CALL EZspline_free(MODB_spl,ier)

#if defined(MPI_OPT)
      CALL MPI_FINALIZE(ierr_mpi)
      IF (ierr_mpi /= MPI_SUCCESS) CALL handle_err(MPI_FINE_ERR,'fieldlines_main:finalize',ierr_mpi)
#endif
      IF (lverb) WRITE(6,'(A)')'----- FIELDLINES DONE -----'
     
!-----------------------------------------------------------------------
!     End Program
!-----------------------------------------------------------------------
      END PROGRAM FIELDLINES
