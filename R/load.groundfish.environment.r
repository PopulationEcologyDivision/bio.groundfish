load.groundfish.environment = function( libs=NULL, p=NULL, assessment.year=NULL  ) {

  if (is.null(p)) p = list()

  # libraries
  p$libs = RLibrary( "Hmisc", "date", "lubridate", "vegan", "fields", "sp",
    "rgdal", "raster" , "INLA", "numDeriv", "lubridate", "geosphere", "parallel" )

  # helper functions
  p$libs = unique( c( p$libs, bioLibrary( "bio.spacetime", "bio.utilities", "bio.taxonomy",
    "netmensuration", "bio.temperature", "bio.habitat", "bio.bathymetry",
    "bio.groundfish", "bio.polygons", "bio.coastline" ) ) )

  if (!is.null(libs)) p$libs = unique( c(p$libs, RLibrary(libs) ) )

  p$R.gs = file.path( project.datadirectory("bio.groundfish"), "R" )

  if (is.null (assessment.year ) ) {
    p$assessment.year = lubridate::year( Sys.Date() )
  } else {
    p$assessment.year = assessment.year
  }

  setwd( p$R.gs )

  # export to calling namespace .. should not be needed but just in case
  assign("R.gs", p$R.gs,  envir=parent.frame() )

  return( p )

}

