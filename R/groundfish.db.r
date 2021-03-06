
groundfish.db = function(  DS="complete", p=NULL, taxa="all", datayrs=NULL  ) {

  loc = file.path( project.datadirectory("bio.groundfish"), "data" )

  DataDumpFromWindows = F
  if ( DataDumpFromWindows ) {
    loc = file.path("C:", "datadump")
  }
  dir.create( path=loc, recursive=T, showWarnings=F )

  if (DS %in% c("odbc.redo") ) {

    # ODBC data dump of bio.groundfish tables
    groundfish.db( DS="gscat.odbc.redo", datayrs=datayrs )
    groundfish.db( DS="gsdet.odbc.redo", datayrs=datayrs )
    groundfish.db( DS="gsinf.odbc.redo", datayrs=datayrs )
    groundfish.db( DS='special.lobster.sampling.redo', datayrs=datayrs)
    #groundfish.db( DS="gshyd.profiles.odbc.redo", datayrs=datayrs )

    groundfish.db( DS="gsmissions.odbc.redo" ) #  not working?

    update.infrequently = F
    if (update.infrequently) {
      # the following do not need to be updated annually
      groundfish.db( DS="gscoords.odbc.redo" )
      groundfish.db( DS="spcodes.odbc.redo" )
      groundfish.db( DS="gslist.odbc.redo" )
      groundfish.db( DS="gsgear.odbc.redo" )
      groundfish.db( DS="gsstratum.odbc.redo" )
    }

  }

# ----------------------

  if (DS %in% c("spcodes", "spcodes.odbc", "spcodes.redo", "spcodes.odbc.redo", "gstaxa", "gstaxa.redo"  ) ) {

    fnspc = file.path( loc, "spcodes.rdata" )

    if ( DS %in% c( "spcodes", "spcodes.odbc", "gstaxa" ) ) {
      load( fnspc )
      return( spcodes )
    }

    if ( DS %in% c( "spcodes.odbc.redo", "spcodes.redo", "gstaxa.redo" ) ) {
      require(RODBC)
      connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user,
          pwd=oracle.personal.password, believeNRows=F)
      spcodes =  sqlQuery(connect, "select * from groundfish.gsspecies", as.is=T)
      odbcClose(connect)
      names(spcodes) =  tolower( names(spcodes) )
      save(spcodes, file=fnspc, compress=T)
      print( fnspc )
      print("Should follow up with a refresh of the taxonomy.db " )
      return( fnspc )
    }
  }


  # --------------------



	if (DS %in% c( "gscat.odbc", "gscat.odbc.redo" ) ) {

    fn.root =  file.path( project.datadirectory("bio.groundfish"), "data", "trawl", "gscat" )
		dir.create( fn.root, recursive = TRUE, showWarnings = FALSE  )

		out = NULL
    if ( is.null(DS) | DS=="gscat.odbc" ) {
      fl = list.files( path=fn.root, pattern="*.rdata", full.names=T )
				for ( fny in fl ) {
				load (fny)
        print(fny)
				out = rbind( out, gscat )
			}
			return (out)
    }

    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user, pwd=oracle.personal.password, believeNRows=F)

		for ( YR in datayrs ) {
			fny = file.path( fn.root, paste( YR,"rdata", sep="."))
      gscat = sqlQuery( connect,  paste(
             "select i.*, substr(mission,4,4) year " ,
      "    from groundfish.gscat i " ,
      "    where substr(MISSION,4,4)=", YR, ";"
      ) )

      names(gscat) =  tolower( names(gscat) )
      dontwant = c("length_type", "length_units", "weight_type",  "weight_units")
      gscat = gscat[,which(!names(gscat)%in%dontwant)]
      print(fny)
      save(gscat, file=fny, compress=T)
			gc()  # garbage collection
			print(YR)
		}

    odbcClose(connect)
    return (fn.root)

	}


  # --------------------



  if (DS %in% c("gscat", "gscat.redo"  ) ) {

    fn = file.path( loc,"gscat.rdata")

    if ( DS=="gscat" ) {
      load( fn )
      print('Not tow length corrected')
      return (gscat)
    }

    gscat = groundfish.db( DS="gscat.odbc" )
    gscat$year = NULL

    # remove data where species codes are ambiguous, or missing or non-living items
    xx = which( !is.finite( gscat$spec) )
    if (length(xx)>0) gscat = gscat[ -xx, ]

    ii = taxonomy.filter.taxa( gscat$spec, taxafilter="living.only", outtype="bio.groundfishcodes" )
    gscat = gscat[ ii , ]

    min.number.observations.required = 3
    species.counts = as.data.frame( table( gscat$spec) )
    species.to.remove = as.numeric( as.character( species.counts[ which( species.counts$Freq < min.number.observations.required) , 1 ] ))

    ii = which( gscat$spec %in% species.to.remove )
    gscat = gscat[ -ii , ]
    gscat$id = paste(gscat$mission, gscat$setno, sep=".")
    gscat$id2 = paste(gscat$mission, gscat$setno, gscat$spec, sep=".")


    # filter out strange data
		ii = which( gscat$totwgt >= 9999 )  # default code for NAs --
    if (length(ii)>0) gscat$totwgt[ii] = NA

		ii = which( gscat$totwgt >= 5000 )  # upper limit of realistic kg/set
    if (length(ii)>0) gscat$totwgt[ii] = 5000

		jj = which( gscat$totwgt == 0 )
		if (length(jj)>0) gscat$totwgt[jj] = NA

		kk = which( gscat$totno == 0 )
    if (length(kk)>0) gscat$totno[kk] = NA

    ll = which( is.na(gscat$totno) & is.na(gscat$totwgt) )
    if (length(ll) > 0) gscat$totno[ ll ] = 1

    # as species codes have been altered, look for duplicates and update totals
    d = which(duplicated(gscat$id2))
    s = NULL
    for (i in d) {
      q = which(gscat$id2 == gscat$id2[i])
			gscat$totno[q[1]] = sum( gscat$totno[q], na.rm=T )
			gscat$totwgt[q[1]] = sum( gscat$totwgt[q], na.rm=T )
			gscat$sampwgt[q[1]] = sum( gscat$sampwgt[q], na.rm=T )
      s = c(s, q[2:length(q)])
    }
    if (length(s)>0) gscat = gscat[-s,]

    oo = which( duplicated( gscat$id2) )
    if ( length( oo )>0 ) {
      print( gscat[ oo , "id2"] )
      stop("Duplcated id2's in gscat"  )
    }

    mw = meansize.crude(Sp=gscat$spec, Tn=gscat$totno, Tw=gscat$totwgt )
    mw2 = meansize.direct()
    mw = merge(mw, mw2, by="spec", all=T, sort=T, suffixes=c(".crude", ".direct") )
    # directly determined mean size has greater reliability --- replace
    mm = which( is.finite(mw$meanweight.direct))
    mw$meanweight = mw$meanweight.crude
    mw$meanweight[mm] = mw$meanweight.direct[mm]
    mw = mw[which(is.finite(mw$meanweight)) ,]


    ii = which( is.na(gscat$totno) & gscat$totwgt >  0 )

    print( "Estimating catches from mean weight information... slow ~ 5 minutes")

    if (length(ii)>0) {
      # replace each number estimate with a best guess based upon average body weight in the historical record
      uu = unique( gscat$spec[ii] )
      for (u in uu ) {
        os =  which( mw$spec==u )
        if (length( os)==0 ) next()
        toreplace = intersect( ii, which( gscat$spec==u) )
        gscat$totno[toreplace] = gscat$totwgt[toreplace] / mw$meanweight[os]
      }
    }

    jj = which( gscat$totno >  0 & is.na(gscat$totwgt) )
    if (length(jj)>0) {
      # replace each number estimate with a best guess based upon average body weight in the historical record
      uu = unique( gscat$spec[jj] )
      for (u in uu ) {
        os =  which( mw$spec==u )
        if (length( os)==0 ) next()
        toreplace = intersect( jj, which( gscat$spec==u) )
        gscat$totwgt[toreplace] = gscat$totno[toreplace] * mw$meanweight[os]
      }
    }

    gscat = gscat[, c("id", "id2", "spec", "totwgt", "totno", "sampwgt" )] # kg, no/set

    save(gscat, file=fn, compress=T)
    return( fn )
  }


  if (DS %in% c('gsdet.spec','gsdet.spec.redo')) {

    fn.root =  file.path( project.datadirectory("bio.groundfish"), "data")
    fi = 'gsdet.spec.rdata'
    dir.create( fn.root, recursive = TRUE, showWarnings = FALSE  )

    if (DS=='gsdet.spec'){
      load(file.path(fn.root,fi))
      return(species.details)
    }

    de  = groundfish.db(DS='gsdet.odbc')
    ins = groundfish.db(DS='gsinf.odbc')
    i1 = which(months(ins$sdate) %in% c('June','July','August'))
    i2 = which(months(ins$sdate) %in% c('February','March','April'))
    i3 = which(ins$strat %in% c(440:495))
    i4 = which(ins$strat %in% c(398:411))
    i5 = which(ins$strat %in% c('5Z1','5Z2','5Z3','5Z4','5Z5','5Z6','5Z7','5Z8','5Z9'))
    ins$series =NA
    ins$series[intersect(i1,i3)] <- 'summer'
    ins$series[intersect(i2,i4)] <- '4vswcod'
    ins$series[intersect(i2,i5)] <- 'georges'

    ins = ins[,c('mission','setno','series')]
    de = merge(de,ins,by=c('mission','setno'))
    de1 = aggregate(clen~spec+year+series,data=de,FUN=sum)
    de2 = aggregate(flen~spec+year+series,data=de,FUN=max)
    de3 = aggregate(flen~spec+year+series,data=de,FUN=min)
    de4 = aggregate(fwt~spec+year+series,data=de,FUN=length)
    species.details = merge(merge(merge(de1,de2,all.x=T,by=c('spec','year','series')),de3,all.x=T,by=c('spec','year','series')),de4,all.x=T,by=c('spec','year','series'))
    names(species.details) <- c('spec','year','series','number.lengths','max.length','min.length','number.weights')
    save(species.details,file=file.path(fn.root,fi))
    return(species.details)
  }


	if (DS %in% c( "gsdet.odbc", "gsdet.odbc.redo" ) ) {
    fn.root =  file.path( project.datadirectory("bio.groundfish"), "data", "trawl", "gsdet" )
		dir.create( fn.root, recursive = TRUE, showWarnings = FALSE  )

		out = NULL
    if ( DS=="gsdet.odbc" ) {
      fl = list.files( path=fn.root, pattern="*.rdata", full.names=T  )
				for ( fny in fl ) {
				load (fny)
				out = rbind( out, gsdet )
			}
			return (out)
    }

    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user, pwd=oracle.personal.password, believeNRows=F)

		for ( YR in datayrs ) {
			fny = file.path( fn.root, paste( YR,"rdata", sep="."))
      gsdet = sqlQuery( connect,  paste(
      "select i.*, substr(mission,4,4) year" ,
      "    from groundfish.gsdet i " ,
      "    where substr(mission,4,4)=", YR, ";"
      ) )
      names(gsdet) =  tolower( names(gsdet) )
      gsdet$mission = as.character( gsdet$mission )
      save(gsdet, file=fny, compress=T)
      print(fny)
			gc()  # garbage collection
			print(YR)
		}
    odbcClose(connect)

    return (fn.root)

	}

  # ----------------------

  if (DS %in% c("gsdet", "gsdet.redo") ) {

  # --------- codes ----------------
  # sex: 0=?, 1=male, 2=female,  3=?
  # mat: 0=observed but undetermined, 1=imm, 2=ripening(1), 3=ripening(2), 4=ripe(mature),
  #      5=spawning(running), 6=spent, 7=recovering, 8=resting
  # settype: 1=stratified random, 2=regular survey, 3=unrepresentative(net damage),
  #      4=representative sp recorded(but only part of total catch), 5=comparative fishing experiment,
  #      6=tagging, 7=mesh/gear studies, 8=explorartory fishing, 9=hydrography
  # --------- codes ----------------


    fn = file.path( loc,"gsdet.rdata")

    if ( DS=="gsdet" ) {
      load( fn )
      return (gsdet)
    }

    gsdet = groundfish.db( DS="gsdet.odbc" )
    gsdet$year = NULL

    oo = which(!is.finite(gsdet$spec) )
    if (length(oo)>0) gsdet = gsdet[-oo,]

    # remove data where species codes are ambiguous, or missing or non-living items
    gsdet = gsdet[ taxonomy.filter.taxa( gsdet$spec, taxafilter="living.only", outtype="bio.groundfishcodes" ) , ]


    gsdet$id = paste(gsdet$mission, gsdet$setno, sep=".")
    gsdet$id2 = paste(gsdet$mission, gsdet$setno, gsdet$spec, sep=".")
    gsdet = gsdet[, c("id", "id2", "spec", "fshno", "fsex", "fmat", "flen", "fwt", "age") ]
    names(gsdet)[which(names(gsdet)=="fsex")] = "sex"
    names(gsdet)[which(names(gsdet)=="fmat")] = "mat"
    names(gsdet)[which(names(gsdet)=="flen")] = "len"  # cm
    names(gsdet)[which(names(gsdet)=="fwt")]  = "mass" # g
    save(gsdet, file=fn, compress=T)

    return( fn )
  }


  # ----------------------


	if (DS %in% c( "gsinf.odbc", "gsinf.odbc.redo" ) ) {

    fn.root =  file.path( project.datadirectory("bio.groundfish"), "data", "trawl", "gsinf" )
		dir.create( fn.root, recursive = TRUE, showWarnings = FALSE  )

		out = NULL
    if ( is.null(DS) | DS=="gsinf.odbc" ) {
      fl = list.files( path=fn.root, pattern="*.rdata", full.names=T  )
				for ( fny in fl ) {
        load (fny)
        out = rbind( out, gsinf )
			}
			return (out)
    }

    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user, pwd=oracle.personal.password, believeNRows=F)

		for ( YR in datayrs ) {
			fny = file.path( fn.root, paste( YR,"rdata", sep="."))
      gsinf = sqlQuery( connect,  paste(
      "select * from groundfish.gsinf where EXTRACT(YEAR from SDATE) = ", YR, ";"
      ) )
      names(gsinf) =  tolower( names(gsinf) )
      save(gsinf, file=fny, compress=T)
      print(fny)
			gc()  # garbage collection
			print(YR)
		}

    odbcClose(connect)
    return (fn.root)

	}



# ----------------------


  if (DS %in% c("gsinf", "gsinf.redo" ) ) {
    fn = file.path( loc, "gsinf.rdata")

    if ( DS=="gsinf" ) {
      load( fn )
      return (gsinf)
    }

    gsinf = groundfish.db( DS="gsinf.odbc" )
    names(gsinf)[which(names(gsinf)=="type")] = "settype"

    gsgear = groundfish.db( DS="gsgear" )
    gsinf = merge (gsinf, gsgear, by="gear", all.x=TRUE, all.y=FALSE, sort= FALSE )

    # fix some time values that have lost the zeros due to numeric conversion
    gsinf$time = as.character(gsinf$time)

    tz.odbc = "America/Halifax"  ## need to verify if this is correct
    tz.groundfish = "UTC"

    # by default it should be the correct timezone ("localtime") , but just in case
    tz( gsinf$sdate) = tz.odbc
    gsinf$sdate = with_tz( gsinf$sdate, tz.groundfish )

    gsinf$edate = gsinf$etime
    tz( gsinf$edate) = tz.odbc
    gsinf$edate = with_tz( gsinf$edate, tz.groundfish )


    # fix sdate - edate inconsistencies .. assuming sdate is correct
    gsinf$timediff.gsinf = gsinf$edate - gsinf$sdate
    oo = which( abs( gsinf$timediff.gsinf)  > dhours( 4 ) )
    if (length(oo)>0) {
      print( "Time stamps sdate and etime (renamed as edate) are severely off (more than 4 hrs):" )
      print( gsinf[oo,] )
      if (FALSE) {
        hist( as.numeric(  gsinf$timediff.gsinf[-oo]), breaks=200 )
        abline (v=30*60, col="red")  # expected value of 30 min
        abline (v=90*60, col="red")  # after 90 min
        abline (v=150*60, col="red")  # after 150 min
      }
    }
    uu = which( gsinf$timediff.gsinf < 0 ) # when tow end is before start
    gsinf$edate[uu]  = NA  # set these to NA until they can be corrected manually
    gsinf$timediff.gsinf[uu] =NA
    print( "Time stamps sdate and etime (renamed as edate) are severely off: edate is before sdate:" )
    print( gsinf[uu,] )

    if (FALSE)  hist( as.numeric(  gsinf$timediff.gsinf), breaks=200 )

    uu = which( gsinf$timediff.gsinf > dminutes(50) & gsinf$timediff.gsinf < dminutes(50+60) ) # assuming 50 min is a max tow length
    if (length(uu)>0) {
      gsinf$edate[uu] = gsinf$edate[uu] - dhours(1) ### this is assuming sdate is correct ... which might not be the case
      if (FALSE) {
        hist( as.numeric(  gsinf$timediff.gsinf[-oo]), breaks=200 )
      }
    }
    gsinf$timediff.gsinf = gsinf$edate - gsinf$sdate
    uu = which( gsinf$timediff.gsinf > dminutes(50) ) # assuming 50 min is a max tow length
    gsinf$edate[uu]  = NA  # set these to NA untile they can be corrected manually
    gsinf$timediff.gsinf[uu] =NA
      if (FALSE) {
        hist( as.numeric(  gsinf$timediff.gsinf), breaks=200 )
        abline (v=30*60, col="red")  # expected value of 30 min
        abline (v=90*60, col="red")  # after 90 min
        abline (v=150*60, col="red")  # after 150 min
      }

    gsinf$yr = lubridate::year( gsinf$sdate)

    gsinf$mission = as.character( gsinf$mission )
    gsinf$strat = as.character(gsinf$strat)
    gsinf$strat[ which(gsinf$strat=="") ] = "NA"
    gsinf$id = paste(gsinf$mission, gsinf$setno, sep=".")
    d = which(duplicated(gsinf$id))
    if (!is.null(d)) write("error: duplicates found in gsinf")

    gsinf$lat = gsinf$slat/100
    gsinf$lon = gsinf$slong/100
    gsinf$lat.end = gsinf$elat/100
    gsinf$lon.end = gsinf$elong/100

    if (mean(gsinf$lon,na.rm=T) >0 ) gsinf$lon = - gsinf$lon  # make sure form is correct
    if (mean(gsinf$lon.end,na.rm=T) >0 ) gsinf$lon.end = - gsinf$lon.end  # make sure form is correct

    gsinf = convert.degmin2degdec(gsinf, vnames=c("lon", "lat") )
    gsinf = convert.degmin2degdec(gsinf, vnames=c("lon.end", "lat.end") )

    gsinf$dist_km = gsinf$dist * 1.852  # nautical mile to km
    gsinf$dist_pos = geosphere::distGeo( gsinf[, c("lon","lat")], gsinf[, c("lon.end", "lat.end")])/1000

    ii = which( abs( gsinf$dist_km) > 10 ) # 10 km is safely too extreme
    if (length(ii)> 0) {
      gsinf$dist_km[ii] =  gsinf$dist_pos[ii]
    }

    ii = which( abs( gsinf$dist_pos) > 10 ) # 10 km is safely too extreme
    if (length(ii)> 0) {
      gsinf$dist_pos[ii] = gsinf$dist_km[ii]
      # assuming end positions are incorrect. This may not be a correct assumption!
      gsinf$lon.end[ii] = NA
      gsinf$lat.end[ii] = NA
    }


  ## !! GPS position-based distances do not always match the distance recorded
  ## plot( dist_pos ~ dist_km, gsinf, ylim=c(0,60))

    gsinf$cftow = 1.75/gsinf$dist  # not used
    ft2m = 0.3048
    m2km = 1/1000
    nmi2mi = 1.1507794
    mi2ft = 5280
    gsinf$sakm2 = (41 * ft2m * m2km ) * ( gsinf$dist * nmi2mi * mi2ft * ft2m * m2km )  # surface area sampled in km^2
			oo = which( !is.finite(gsinf$sakm2 ))
				gsinf$sakm2[oo] = median (gsinf$sakm2, na.rm=T)
			pp = which( gsinf$sakm2 > 0.09 )
				gsinf$sakm2[pp] = median (gsinf$sakm2, na.rm=T)
    gsinf$bottom_depth = rowMeans( gsinf[, c("dmax", "depth" )], na.rm = TRUE )  * 1.8288  # convert from fathoms to meters
    ii = which( gsinf$bottom_depth < 10 | !is.finite(gsinf$bottom_depth)  )  # error
    gsinf$bottom_depth[ii] = NA
		gsinf = gsinf[, c("id", "yr", "sdate", "edate", "time", "strat", "area", "speed", "dist_km", "dist_pos",
                      "cftow", "sakm2", "settype", "gear", "geardesc", "lon", "lat", "lon.end", "lat.end",
                      "surface_temperature","bottom_temperature","bottom_salinity", "bottom_depth")]

    save(gsinf, file=fn, compress=T)
    return(fn)
  }


# -------------


	if (DS %in% c( "gshyd.profiles.odbc" , "gshyd.profiles.odbc.redo" ) ) {

    fn.root =  file.path( project.datadirectory("bio.groundfish"), "data", "trawl", "gshyd" )
		dir.create( fn.root, recursive = TRUE, showWarnings = FALSE  )

		out = NULL
    if ( is.null(DS) | DS=="gshyd.profiles.odbc" ) {
      fl = list.files( path=fn.root, pattern="*.rdata", full.names=T  )
				for ( fny in fl ) {
				load (fny)
				out = rbind( out, gshyd )
			}
			return (out)
    }

    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user, pwd=oracle.personal.password, believeNRows=F)

		for ( YR in datayrs ) {
			fny = file.path( fn.root, paste( YR,"rdata", sep="."))
      gshyd = sqlQuery( connect,  paste(
      "select i.*, j.YEAR " ,
      "    from groundfish.gshyd i, groundfish.gsmissions j " ,
      "    where i.MISSION(+)=j.MISSION " ,
      "    and YEAR=", YR, ";"
      ) )
      names(gshyd) =  tolower( names(gshyd) )
      if(all(is.na(gshyd$mission))) {
      	#if gshyd is not loaded and the odf files are obtained AMC
	        fy <- file.path(project.datadirectory("bio.temperature"), "data", "archive", "ctd",YR)
	        o <- compileODF(path=fy)
	        gshyd <- makeGSHYD(o)
      }
      gshyd$mission = as.character( gshyd$mission )
      save(gshyd, file=fny, compress=T)
      print(fny)
			gc()  # garbage collection
			print(YR)
		}
		odbcClose(connect)

    return ( fn.root )

	}

# ----------------------



  if (DS %in% c("gshyd.profiles", "gshyd.profiles.redo" ) ) {
    # full profiles
    fn = file.path( loc,"gshyd.profiles.rdata")
    if ( DS=="gshyd.profiles" ) {
      load( fn )
      return (gshyd)
    }

    gshyd = groundfish.db( DS="gshyd.profiles.odbc" )
    gshyd$id = paste(gshyd$mission, gshyd$setno, sep=".")
    gshyd = gshyd[, c("id", "sdepth", "temp", "sal", "oxyml" )]
    save(gshyd, file=fn, compress=T)
    return( fn )
  }


# ----------------------



  if (DS %in% c("gshyd", "gshyd.redo") ) {
    # hydrographic info at deepest point
    fn = file.path( loc,"gshyd.rdata")
    if ( DS=="gshyd" ) {
      load( fn )
      return (gshyd)
    }
    gshyd = groundfish.db( DS="gshyd.profiles" )
    nr = nrow( gshyd)

    # candidate depth estimates from profiles
    deepest = NULL
    t = which( is.finite(gshyd$sdepth) )
    id = unique(gshyd$id)
    for (i in id) {
      q = intersect( which( gshyd$id==i), t )
      r = which.max( gshyd$sdepth[q] )
      deepest = c(deepest, q[r])
    }
    gshyd = gshyd[deepest,]
    oo = which( duplicated( gshyd$id ) )
    if (length(oo) > 0) stop( "Duplicated data in GSHYD" )

    gsinf = groundfish.db( "gsinf" )
    gsinf = gsinf[, c("id", "bottom_temperature", "bottom_salinity", "bottom_depth" ) ]
    gshyd = merge( gshyd, gsinf, by="id", all.x=T, all.y=F, sort=F )

    ## bottom_depth is a profile-independent estimate .. asuming it has higher data quality
    ii = which(!is.finite( gshyd$bottom_depth ))
    if (length(ii)>0) gshyd$bottom_depth[ii] = gshyd$sdepth[ii]
    gshyd$sdepth = gshyd$bottom_depth        #overwrite
    ii = which( gshyd$sdepth < 10 )
    if (length(ii)>0) gshyd$sdepth[ii] = NA

    ii = which( is.na( gshyd$temp) )
    if (length(ii)>0) gshyd$temp[ii] =  gshyd$bottom_temperature[ii]

    jj = which( is.na( gshyd$sal) )
    if (length(jj)>0) gshyd$sal[jj] =  gshyd$bottom_salinity[jj]
    gshyd$sal[gshyd$sal<5 ] = NA

    gshyd$bottom_depth = NULL
    gshyd$bottom_temperature = NULL
    gshyd$bottom_salinity = NULL


    save(gshyd, file=fn, compress=T)
    return( fn )
  }

# ----------------------



  if (DS %in% c("gshyd.georef", "gshyd.georef.redo") ) {
    # hydrographic info georeferenced
    fn = file.path( loc,"gshyd.georef.rdata")
    if ( DS=="gshyd.georef" ) {
      load( fn )
      return (gshyd)
    }
    gsinf = groundfish.db( "gsinf" )
    gsinf$timestamp = gsinf$sdate
    gsinf$yr = lubridate::year( gsinf$timestamp)
    gsinf$longitude = gsinf$lon
    gsinf$latitude = gsinf$lat
    gsinf = gsinf[ , c( "id", "lon", "lat", "yr", "timestamp" ) ]
    gshyd = groundfish.db( "gshyd.profiles" )
    gshyd = merge( gshyd, gsinf, by="id", all.x=T, all.y=F, sort=F )
    gshyd$sal[gshyd$sal<5]=NA
    save(gshyd, file=fn, compress=T)
    return( fn )
  }


  # ----------------------


  if (DS %in% c("gsstratum", "gsstratum.obdc.redo") ) {
    fn = file.path( loc,"gsstratum.rdata")
    if ( DS=="gsstratum" ) {
      load( fn )
      return (gsstratum)
    }
    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user,
        pwd=oracle.personal.password, believeNRows=F)
    gsstratum =  sqlQuery(connect, "select * from groundfish.gsstratum", as.is=T)
    odbcClose(connect)
    names(gsstratum) =  tolower( names(gsstratum) )
    save(gsstratum, file=fn, compress=T)
    print(fn)
    return( fn )
  }


  # ----------------------


  if (DS %in% c("gsgear", "gsgear.odbc.redo") ) {
    fn = file.path( loc,"gsgear.rdata")
    if ( DS=="gsgear" ) {
      load( fn )
      return (gsgear)
    }
    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user,
        pwd=oracle.personal.password, believeNRows=F)
    gsgear =  sqlQuery(connect, "select * from groundfish.gsgear", as.is=T)
    odbcClose(connect)
    names(gsgear) =  tolower( names(gsgear) )
    save(gsgear, file=fn, compress=T)
    print(fn)
    return( fn )
  }



  # ----------------------


  if (DS %in% c("gscoords", "gscoords.odbc.redo") ) {
    # detailed list of places, etc
    fn = file.path( loc,"gscoords.rdata")
    if ( DS=="gscoords" ) {
      load( fn )
      return (gscoords)
    }
    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user,
        pwd=oracle.personal.password, believeNRows=F)
    coords = sqlQuery(connect, "select * from mflib.mwacon_mapobjects", as.is=T)
    odbcClose(connect)
    names(coords) =  tolower( names(coords) )
    save(coords, file=fn, compress=T)
    print(fn)
    return( fn )
  }

# ----------------------


 if (DS %in% c("gslist", "gslist.odbc.redo") ) {
    fn = file.path( loc,"gslist.rdata")
    if ( DS=="gslist" ) {
      load( fn )
      return (gslist)
    }
    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user,
        pwd=oracle.personal.password, believeNRows=F)
    gslist = sqlQuery(connect, "select * from groundfish.gs_survey_list")
    odbcClose(connect)
    names(gslist) =  tolower( names(gslist) )
    save(gslist, file=fn, compress=T)
    print(fn)
    return( fn )
  }

# ----------------------

  if (DS %in% c("gsmissions", "gsmissions.odbc.redo") ) {
    fnmiss = file.path( loc,"gsmissions.rdata")

    if ( DS=="gsmissions" ) {
      load( fnmiss )
      return (gsmissions)
    }

    require(RODBC)
    connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user,
        pwd=oracle.personal.password, believeNRows=F)
      gsmissions = sqlQuery(connect, "select MISSION, VESEL, CRUNO from groundfish.gsmissions")
      odbcClose(connect)
      names(gsmissions) =  tolower( names(gsmissions) )
      save(gsmissions, file=fnmiss, compress=T)
    print(fnmiss)
    return( fnmiss )
  }

# ----------------------

  if (DS %in% c("cat.base", "cat.base.redo") ) {
    fn = file.path( project.datadirectory("bio.groundfish"), "data", "cat.base.rdata")
    if ( DS=="cat.base" ) {
      load( fn )
      return (cat)
    }

    gscat = groundfish.db( "gscat" ) #kg/set, no/set
    set = groundfish.db( "set.base" )
    cat = merge(x=gscat, y=set, by=c("id"), all.x=T, all.y=F, sort=F)
    rm (gscat, set)

    gstaxa = taxonomy.db( "life.history" )
    gstaxa = gstaxa[,c("spec", "name.common", "name.scientific", "itis.tsn" )]
    oo = which( duplicated( gstaxa$spec ) )
    if (length( oo) > 0 ) {
      gstaxa = gstaxa[ -oo , ]  # arbitrarily drop subsequent matches
      print( "NOTE -- Duplicated species codes in taxonomy.db(life.history) ... need to fix taxonomy.db, dropping for now " )
    }

    cat = merge(x=cat, y=gstaxa, by=c("spec"), all.x=T, all.y=F, sort=F)
    save(cat, file=fn, compress=T )
    return ( fn )
  }

   # ----------------------

  if (DS %in% c("det.base", "det.base.redo") ) {
    fn = file.path( project.datadirectory("bio.groundfish"), "data", "det.base.rdata")
    if ( DS=="det.base" ) {
      load( fn )
      return (det)
    }

    det = groundfish.db( "gsdet" )

    det = det[, c("id", "id2", "spec", "fshno", "sex", "mat", "len", "mass", "age") ]
    det$mass = det$mass / 1000 # convert from g to kg

    save( det, file=fn, compress=T )
    return( fn )
  }


# ----------------------

  if (DS %in% c("cat", "cat.redo") ) {
    fn = file.path( project.datadirectory("bio.groundfish"), "data", "cat.rdata")
    if ( DS=="cat" ) {
      load( fn )
      return (cat)
    }

    cat = groundfish.db( DS="cat.base" )  # kg/set, no/set

    # combine correction factors or ignore trapability corrections ..
    # plaice correction ignored as they are size-dependent
    cat = correct.vessel(cat)  # returns cfvessel

    # many cases have measurements but no subsampling info
    # ---- NOTE ::: sampwgt seems to be unreliable  -- recompute where necessary in "det"

    # the following conversion are done here as sakm2 s not available in "gscat"
    # .. needs to be merged before use from gsinf
    # surface area of 1 standard set: sa =  41 (ft) * N  (nmi); N==1.75 for a standard trawl
    # the following express per km2 and so there is no need to "correct"  to std tow.

    cat$totwgt  = cat$totwgt  * cat$cfset * cat$cfvessel # convert kg/set to kg/km^2
    cat$totno   = cat$totno   * cat$cfset * cat$cfvessel # convert number/set to number/km^2

    # cat$sampwgt is unreliable for most data points nned to determine directly from "det"
    cat$sampwgt = NULL

    # cat$cfsampling = cat$totwgt / cat$sampwgt
    # cat$cfsampling[ which( !is.finite(cat$cfsampling)) ] = 1 # can only assume everything was measured (conservative estimate)


    # cat$sampwgt =  cat$sampwgt * cat$cf   # keep same scale as totwgt to permit computations later on

    save(cat, file=fn, compress=T )

    return (fn)
  }



# ----------------------



  if (DS %in% c("det", "det.redo") ) {
    fn = file.path( project.datadirectory("bio.groundfish"), "data", "det.rdata")
    if ( DS=="det" ) {
      load( fn )
      return (det)
    }

    # determine weighting factor for individual-level measurements (len, weight, condition, etc)

    # at the set level, some species are not sampled even though sampwgt's are recorded
    # this makes the total biomass > than that estimated from "DET"
    # an additional correction factor is required to bring it back to the total biomass caught,
    # this must be aggregated across all species within each set :

    # correction factors for sampling etc after determination of mass and len
    # for missing data due to subsampling methodology
    # totals in the subsample that was taken should == sampwgt (in theory) but do not
    # ... this is a rescaling of the sum to make it a 'proper' subsample

    det = groundfish.db( "det.base" )  # kg, cm

    massTotCat = applySum( det[ ,c("id2", "mass")], newnames=c("id2","massTotdet" ) )
    noTotCat = applySum( det$id2, newnames=c("id2","noTotdet" ) )

    cat = groundfish.db( "cat" ) # kg/km^2 and  no/km^2
    cat = cat[, c("id2", "totno", "totwgt", "cfset", "cfvessel" )]
    cat = merge( cat, massTotCat, by="id2", all.x=T, all.y=F, sort=F )  # set-->kg/km^2, det-->km
    cat = merge( cat, noTotCat, by="id2", all.x=T, all.y=F, sort=F )    # set-->no/km^2, det-->no

    cat$cfdet =  cat$totwgt/ cat$massTotdet  # totwgt already corrected for vessel and tow .. cfdet is the multiplier required to make each det measurement scale properly

    # assume no subsampling -- all weights determined from the subsample
    oo = which ( !is.finite( cat$cfdet ) |  cat$cfdet==0 )
    if (length(oo)>0) cat$cfdet[oo] = cat$cfset[oo] * cat$cfvessel[oo]

    # assume remaining have an average subsampling effect
    oo = which ( !is.finite( cat$cfdet ) |  cat$cfdet==0 )
    if (length(oo)>0) cat$cfdet[oo] = median( cat$cfdet, na.rm=TRUE )

    cat = cat[, c("id2", "cfdet")]
    det = merge( det, cat, by="id2", all.x=T, all.y=F, sort=F)

    save( det, file=fn, compress=T )
    return( fn  )
  }

# -------


if (DS %in% c("sweptarea", "sweptarea.redo" )) {
  # merge bottom contact data into the main gsinf table and
  # then do some sanity checks on the SA estimates and
  # then compute best estimates where data are missing

  fn = file.path( loc, "gsinf.sweptarea.rdata" )

  if (DS=="sweptarea") {
    gsinf = NULL
    if (file.exists(fn)) load(fn)
    return( gsinf )
  }

  p = bio.groundfish::load.groundfish.environment()

  gsinf = groundfish.db( DS="gsinf" )
  gsinf_bc = scanmar.db( DS="bottom.contact", p=p )

  toreject = which( !is.na( gsinf_bc$bc.error.flag ) )

  gsinf_bc$wing.sa [ toreject] = NA
  gsinf_bc$door.sa [ toreject] = NA

  newvars = setdiff( names( gsinf_bc ), names( gsinf)  )
  tokeep = c("id", newvars )

  ng = nrow( gsinf)
  gsinf = merge( gsinf, gsinf_bc[,tokeep], by="id", all.x=TRUE, all.y=FALSE )
  if ( ng != nrow(gsinf) ) error("merge error" )

  gsinf$dist_wing = gsinf$wing.sa / gsinf$wing.mean * 1000  # est of length of the tow (km)
  gsinf$dist_door = gsinf$door.sa / gsinf$door.mean * 1000 # est of length of the tow (km)
  gsinf$yr = lubridate::year(gsinf$sdate)

    # empirical distribution suggests (above)  hard limits of rn, ~ same as gating limits
    # .. too extreme means interpolation did not work well .. drop
    qnts = c( 0.005, 0.995 )
    w2a = which( gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5) )     # for distribution checks for western IIA trawl

    if (0) hist( gsinf$wing.mean[w2a], "fd", xlim=c( 8,22) )
    rn = quantile( gsinf$wing.mean[w2a], probs=qnts, na.rm=TRUE )  # ranges from 11 to 20
    i = which( (gsinf$wing.mean < rn[1] | gsinf$wing.mean > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5)  )
    if ( length(i) > 0) {
      gsinf$wing.mean[i] = NA
      gsinf$wing.sa[i] = NA
      gsinf$wing.sd[i] = NA
    }

    if (0) hist( gsinf$door.mean[w2a], "fd", xlim=c( 0, 85 ) )
    rn = quantile( gsinf$door.mean[w2a], probs=qnts, na.rm=TRUE )  # ranges from 13 to 79
    i = which( (gsinf$door.mean < rn[1] | gsinf$door.mean > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5)  )
    if ( length(i) > 0) {
      gsinf$door.mean[i] = NA
      gsinf$door.sa[i] = NA
      gsinf$door.sd[i] = NA
    }

    # unreliable SD
    if (0) hist( gsinf$wing.sd[w2a], "fd", xlim=c( 0.1, 5 ) )
    rn = quantile( gsinf$wing.sd[w2a], probs=qnts, na.rm=TRUE )  # ranges from 0.16 to 3.62
    i = which( (gsinf$wing.sd < rn[1] | gsinf$wing.sd > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5) )
    if ( length(i) > 0) {
      gsinf$wing.mean[i] = NA
      gsinf$wing.sa[i] = NA
      gsinf$wing.sd[i] = NA
    }

    if (0) hist( gsinf$door.sd[w2a], "fd", xlim=c( 0.1, 25 ) )
    rn = quantile( gsinf$door.sd[w2a], probs=qnts, na.rm=TRUE )  # ranges from 0.42 to 16 .. using 0.1 to 20
    i = which( (gsinf$door.sd < rn[1] | gsinf$door.sd > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5) )
    if ( length(i) > 0) {
      gsinf$door.mean[i] = NA
      gsinf$door.sa[i] = NA
      gsinf$door.sd[i] = NA
    }

    # unreliable SA's
    if (0) hist( gsinf$wing.sa[w2a], "fd", xlim=c( 0.01, 0.08 ) )
    rn = quantile( gsinf$wing.sa[w2a], probs=qnts, na.rm=TRUE )  # ranges from 0.02 to 0.064 .. using 0.01 to 0.08
    i = which( (gsinf$wing.sa < rn[1] | gsinf$wing.sa > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5) )
    if ( length(i) > 0) {
      gsinf$wing.mean[i] = NA
      gsinf$wing.sa[i] = NA
      gsinf$wing.sd[i] = NA
    }


    if (0) hist( gsinf$door.sa[w2a], "fd" , xlim=c( 0.02, 0.30 ))
    rn = quantile( gsinf$door.sa[w2a], probs=qnts, na.rm=TRUE )  # ranges from 0.04 to 0.25 .. using 0.02 to 0.30
    i = which( (gsinf$door.sa < rn[1] | gsinf$door.sa > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5)  )
    if ( length(i) > 0) {
      gsinf$door.mean[i] = NA
      gsinf$door.sa[i] = NA
      gsinf$door.sd[i] = NA
    }


    # tow length est
    if (0) hist( gsinf$dist_wing[w2a], "fd", xlim=c( 1.75, 4.5 ) )
    rn = quantile( gsinf$dist_wing[w2a], probs=qnts, na.rm=TRUE )  # ranges from 2.06 to 4.2 .. using 1.75 to 4.5
    i = which( (gsinf$dist_wing < rn[1] | gsinf$dist_wing > rn[2] ) & gsinf$geardesc == "Western IIA trawl"  & gsinf$settype %in% c(1,2,5) )
    if ( length(i) > 0) {
      gsinf$dist_wing[i] = NA
      gsinf$wing.mean[i] = NA
      gsinf$wing.sa[i] = NA
      gsinf$wing.sd[i] = NA
    }

    if (0) hist( gsinf$dist_door[w2a], "fd", xlim=c( 1.75, 4.5 )  )
    rn = quantile( gsinf$dist_door[w2a], probs=qnts, na.rm=TRUE )  # ranges from 2.03 to 4.2 .. using 1.75 to 4.5
    i = which( (gsinf$dist_door < rn[1] | gsinf$dist_door > rn[2] ) & gsinf$geardesc == "Western IIA trawl" & gsinf$settype %in% c(1,2,5)  )
    if ( length(i) > 0) {
      gsinf$dist_door[i] = NA
      gsinf$door.mean[i] = NA
      gsinf$door.sa[i] = NA
      gsinf$door.sd[i] = NA
    }

    # basic (gating) sanity checks finished ..
    # now estimate swept area for data locations where estimates
    # do not exist or are problematic from bottom contact approach

    ## dist_km is logged distance in gsinf
    ## dist_pos is distance based upon logged start/end locations
    ## dist_bc is distance from bottom contact analysis
    ## dist_wing / dist_door .. back caluculated distance from SA

    # estimate distance of tow track starting with most reliable to least
    gsinf$distance = NA
    gsinf$distance[w2a] = gsinf$dist_wing[w2a]

    ii = intersect( which( !is.finite( gsinf$distance ) ) , w2a)
    if (length(ii) > 0) gsinf$distance[ii] = gsinf$dist_door[ii]

    ii = intersect( which( !is.finite( gsinf$distance ) ), w2a )
    if (length(ii) > 0) gsinf$distance[ii] = gsinf$dist_pos[ii]

    ii = intersect( which( !is.finite( gsinf$distance ) ), w2a )
    if (length(ii) > 0) gsinf$distance[ii] = gsinf$dist_km[ii]



    # wing and door spread models
    # there are differences due to nets config and/or sensors each year ..
    require(mgcv)
    gsinf$yr0 = gsinf$yr  # yr will be modified to permit prediction temporarilly

    ii = intersect( which( !is.finite( gsinf$wing.mean )) , w2a )
    if (length(ii)>0 & length(which( is.finite( gsinf$wing.mean))) > 100 ) {
      wm = gam( wing.mean ~ factor(yr) + s(lon,lat) + s(bottom_depth)+s(door.mean), data= gsinf[ w2a,] )
#R-sq.(adj) =  0.633   Deviance explained = 64.2%
#GCV = 3.3434  Scale est. = 3.2603    n = 1774
      jj = which( ! gsinf$yr %in% as.numeric(as.character(wm$xlevels[["factor(yr)"]])) )
      if (length(jj)>0) gsinf$yr[jj] = 2004  # to minimise discontinuity across year (and also visually close to median level)
      gsinf$wing.mean[ii] = predict( wm, newdata=gsinf[ii,], type="response" )
      gsinf$wing.sd[ii] = NA  # ensure sd is NA to mark it as having been estimated after the fact
    }


    ii = intersect( which( !is.finite( gsinf$wing.mean )) , w2a )
    if (length(ii)>0 & length(which( is.finite( gsinf$wing.mean))) > 100 ) {
      wm = gam( wing.mean ~ factor(yr) + s(lon,lat) + s(bottom_depth), data= gsinf[ intersect( w2a, which(! is.na(gsinf$wing.sd))),] )
# summary(wm)
#R-sq.(adj) =  0.591   Deviance explained = 60.1%
#GCV = 3.7542  Scale est. = 3.6646    n = 1795
      jj = which( ! gsinf$yr %in% as.numeric(as.character(wm$xlevels[["factor(yr)"]])) )
      if (length(jj)>0) gsinf$yr[jj] = 2004  # to minimise discontinuity across year (and also visually close to median level)
      gsinf$wing.mean[ii] = predict( wm, newdata=gsinf[ii,], type="response" )
      gsinf$wing.sd[ii] = NA  # ensure sd is NA to mark it as having been estimated after the fact
    }


    ii = intersect( which( !is.finite( gsinf$wing.mean )) , w2a )
    if (length(ii)>0 & length(which( is.finite( gsinf$wing.mean))) > 100 ) {
       wm = gam( wing.mean ~ factor(yr) + s(lon,lat) , data= gsinf[ intersect( w2a, which(! is.na(gsinf$wing.sd))),] )
# summary(wm)
# R-sq.(adj) =  0.509   Deviance explained = 51.9%
# GCV = 4.5011  Scale est. = 4.4031    n = 1795
      jj = which( ! gsinf$yr %in% as.numeric(as.character(wm$xlevels[["factor(yr)"]])) )
      if (length(jj)>0) gsinf$yr[jj] = 2004  # to minimise discontinuity across year (and also visually close to median level)
      gsinf$wing.mean[ii] = predict( wm, newdata=gsinf[ii,], type="response" )
      gsinf$wing.sd[ii] = NA  # ensure sd is NA to mark it as having been estimated after the fact
    }


    ii = intersect( which( !is.finite( gsinf$door.mean )), w2a )
    if (length(ii)>0 & length(which( is.finite( gsinf$door.mean))) > 100 ) {
      wd = gam( door.mean ~ factor(yr) + s(lon,lat) + s(bottom_depth)+s(wing.mean), data= gsinf[w2a,] )
#R-sq.(adj) =  0.654   Deviance explained = 66.3%
#GCV = 86.858  Scale est. = 84.594    n = 1454
      jj = which( ! as.character( gsinf$yr0) %in%  wd$xlevels[["factor(yr)"]] )
      if (length(jj)>0) gsinf$yr[jj] = 2004  # to minimise discontinuity across year (and also visually close to median level)
      gsinf$door.mean[ii] = predict( wd, newdata=gsinf[ii,], type="response" )
      gsinf$door.sd[ii] = NA  # ensure sd is NA to mark it as having been estimated after the fact
    }

    ii = intersect( which( !is.finite( gsinf$door.mean )), w2a )
    if (length(ii)>0 & length(which( is.finite( gsinf$door.mean))) > 100 ) {
      wd = gam( door.mean ~ factor(yr) + s(lon,lat) + s(bottom_depth), data= gsinf[ intersect( w2a, which(! is.na(gsinf$door.sd))),] )
      #      summary(wd)
# R-sq.(adj) =   0.58   Deviance explained = 59.2%
# GCV = 105.65  Scale est. = 102.61    n = 1454
      jj = which( ! as.character( gsinf$yr0) %in%  wd$xlevels[["factor(yr)"]] )
      if (length(jj)>0) gsinf$yr[jj] = 2004  # to minimise discontinuity across year (and also visually close to median level)
      gsinf$door.mean[ii] = predict( wd, newdata=gsinf[ii,], type="response" )
      gsinf$door.sd[ii] = NA  # ensure sd is NA to mark it as having been estimated after the fact
    }

    ii = intersect( which( !is.finite( gsinf$door.mean )), w2a )
    if (length(ii)>0 & length(which( is.finite( gsinf$door.mean))) > 100 ) {
      wd = gam( door.mean ~ factor(yr) + s(lon,lat) , data= gsinf[ intersect( w2a, which(! is.na(gsinf$door.sd))),] )
      #      summary(wd)
#R-sq.(adj) =  0.486   Deviance explained = 50.2%
#GCV = 2.2601  Scale est. = 2.1869    n = 1209
      jj = which( ! as.character( gsinf$yr0) %in%  wd$xlevels[["factor(yr)"]] )
      if (length(jj)>0) gsinf$yr[jj] = 2004  # to minimise discontinuity across year (and also visually close to median level)
      gsinf$door.mean[ii] = predict( wd, newdata=gsinf[ii,], type="response" )
      gsinf$door.sd[ii] = NA  # ensure sd is NA to mark it as having been estimated after the fact
    }


    # return correct years to data
    gsinf$yr =gsinf$yr0
    gsinf$yr0 = NULL

    # estimate SA:
    gsinf$wing.sa.crude = gsinf$distance * gsinf$wing.mean /1000
    gsinf$door.sa.crude = gsinf$distance * gsinf$door.mean /1000

    # gating
    bad = intersect( which( gsinf$wing.sa.crude > 0.09 ) , w2a)
    gsinf$wing.sa.crude[bad] = NA

    bad = intersect( which( gsinf$door.sa.crude > 0.03 ), w2a)
    gsinf$door.sa.crude[bad] = NA

    bad = intersect( which( gsinf$wing.sa > 0.09 ) , w2a)
    gsinf$wing.sa[bad] = NA

    bad = intersect( which( gsinf$door.sa > 0.03 ), w2a)
    gsinf$door.sa[bad] = NA

    ## create sweptarea :
    gsinf$sweptarea = gsinf$wing.sa

    ii = intersect( which( !is.finite( gsinf$sweptarea ) ), w2a)
    if (length(ii) > 0) gsinf$sweptarea[ii] = gsinf$wing.sa.crude[ii]

    ii = intersect( which( !is.finite( gsinf$door.sa ) ), w2a)
    if (length(ii) > 0) gsinf$door.sa[ii] = gsinf$door.sa.crude[ii]

    sayrw =  tapply( gsinf$wing.sa, gsinf$yr, mean, na.rm=TRUE)
    sayrp =  tapply( gsinf$sakm2, gsinf$yr, mean, na.rm=TRUE)
    sayrwc =  tapply( gsinf$wing.sa.crude, gsinf$yr, mean, na.rm=TRUE)

    ii = intersect( which( !is.finite( gsinf$sweptarea ) ), w2a)
    if (length(ii) > 0 ) gsinf$sweptarea[ii] = sayrw[as.character(gsinf$yr[ii])]

    ii = intersect( which( !is.finite( gsinf$sweptarea ) ), w2a)
    if (length(ii) > 0 ) gsinf$sweptarea[ii] = sayrwc[as.character(gsinf$yr[ii])]

    ii = intersect( which( !is.finite( gsinf$sweptarea ) ), w2a)
    if (length(ii) > 0 ) gsinf$sweptarea[ii] = sayrp[as.character(gsinf$yr[ii])]


    # surface area / areal expansion correction factor: cfset

    gsinf$cfset = 1 / gsinf$sweptarea
    nodata = which( !is.finite( gsinf$cfset ))
#    browser( ) ## check

  save( gsinf, file=fn, compress=TRUE )

  return( fn )
}


# ----------------------


  if (DS %in% c("set.base", "set.base.redo") ) {
    fn = file.path( project.datadirectory("bio.groundfish"), "data", "set.base.rdata")
    if ( DS=="set.base" ) {
      load( fn )
      return ( set )
    }
    gsinf = groundfish.db( "sweptarea" )
    gshyd = groundfish.db( "gshyd" ) # already contains temp data from gsinf
    set = merge(x=gsinf, y=gshyd, by=c("id"), all.x=TRUE, all.y=FALSE, sort=FALSE)
    rm (gshyd, gsinf)
    oo = which( !is.finite( set$sdate)) # NED1999842 has no accompanying gsinf data ... drop it
    if (length(oo)>0) set = set[ -oo  ,]
    set$timestamp = set$sdate
    if (length(which(duplicated(set$id)))>0 ) stop("Duplicates found ...")
    set$oxysat = compute.oxygen.saturation( t.C=set$temp, sal.ppt=set$sal, oxy.ml.l=set$oxyml)
    save ( set, file=fn, compress=T)
    return( fn  )
  }


  # ----------------------


  if (DS %in% c("catchbyspecies", "catchbyspecies.redo") ) {
   fn = file.path( project.datadirectory("bio.groundfish"), "data", "set.catchbyspecies.rdata")
   if ( DS=="catchbyspecies" ) {
     load( fn )
     return ( set )
   }

    set = groundfish.db( "set.base" ) [, c("id", "yr")] # yr to maintain data structure

    # add dummy variables to force merge suffixes to register
    set$totno = NA
    set$totwgt = NA
    set$ntaxa = NA
    cat = groundfish.db( "cat" )
    cat = cat[ which(cat$settype %in% c(1,2,5)) , ]  # required only here

  # settype: 1=stratified random, 2=regular survey, 3=unrepresentative(net damage),
  #  4=representative sp recorded(but only part of total catch), 5=comparative fishing experiment,
  #  6=tagging, 7=mesh/gear studies, 8=explorartory fishing, 9=hydrography

    cat0 = cat[, c("id", "spec", "totno", "totwgt")]
    rm(cat); gc()
    for (tx in taxa) {
      print(tx)
      i = taxonomy.filter.taxa( cat0$spec, taxafilter=tx, outtype="bio.groundfishcodes" )
      cat = cat0[i,]
      index = list(id=cat$id)
      qtotno = tapply(X=cat$totno, INDEX=index, FUN=sum, na.rm=T)
      qtotno = data.frame(totno=as.vector(qtotno), id=I(names(qtotno)))
      qtotwgt = tapply(X=cat$totwgt, INDEX=index, FUN=sum, na.rm=T)
      qtotwgt = data.frame(totwgt=as.vector(qtotwgt), id=I(names(qtotwgt)))
      qntaxa = tapply(X=rep(1, nrow(cat)), INDEX=index, FUN=sum, na.rm=T)
      qntaxa = data.frame(ntaxa=as.vector(qntaxa), id=I(names(qntaxa)))
      qs = merge(qtotno, qtotwgt, by=c("id"), sort=F, all=T)
      qs = merge(qs, qntaxa, by=c("id"), sort=F, all=T)
      set = merge(set, qs, by=c("id"), sort=F, all.x=T, all.y=F, suffixes=c("", paste(".",tx,sep="")) )
    }
    set$totno = NULL
    set$totwgt = NULL
    set$ntaxa = NULL
    set$yr = NULL
    save ( set, file=fn, compress=T)
    return( fn  )
  }


  # ----------------------


  if (DS %in% c("set.det", "set.det.redo") ) {
    fn = file.path( project.datadirectory("bio.groundfish"), "data", "set_det.rdata")
    if ( DS=="set.det" ) {
      load( fn )
      return ( set )
    }

    require (Hmisc)
    set = groundfish.db( "set.base" ) [, c("id", "yr")] # yr to maintain data structure
    newvars = c( "mmean", "lmean", "msd", "lsd")
    dummy = as.data.frame( array(data=NA, dim=c(nrow(set), length(newvars) )))
    names (dummy) = newvars
    set = cbind(set, dummy)

    det = groundfish.db( "det" )

    #det = det[ which(det$settype %in% c(1, 2, 4, 5, 8) ) , ]
  # settype: 1=stratified random, 2=regular survey, 3=unrepresentative(net damage),
  #  4=representative sp recorded(but only part of total catch), 5=comparative fishing experiment,
  #  6=tagging, 7=mesh/gear studies, 8=explorartory fishing, 9=hydrography
    det$mass = log10( det$mass )
    det$len  = log10( det$len )

#       det0 = det[, c("id", "spec", "mass", "len", "age", "residual", "pvalue", "cf")]
     det0 = det[, c("id", "spec", "mass", "len", "age", "cfdet")]
    rm (det); gc()

    for (tx in taxa) {
      print(tx)
      if (tx %in% c("northernshrimp") ) next
      i = taxonomy.filter.taxa( det0$spec, taxafilter=tx, outtype="bio.groundfishcodes"  )
      det = det0[i,]
      index = list(id=det$id)

      # using by or aggregate is too slow: raw computation is fastest using the fast formula: sd = sqrt( sum(x^2)-sum(x)^2/(n-1) ) ... as mass, len and resid are log10 transf. .. they are geometric means

      mass1 = tapply(X=det$mass*det$cfdet, INDEX=index, FUN=sum, na.rm=T)
      mass1 = data.frame(mass1=as.vector(mass1), id=I(names(mass1)))

      mass2 = tapply(X=det$mass*det$mass*det$cfdet, INDEX=index, FUN=sum, na.rm=T)
      mass2 = data.frame(mass2=as.vector(mass2), id=I(names(mass2)))

      len1 = tapply(X=det$len*det$cfdet, INDEX=index, FUN=sum, na.rm=T)
      len1 = data.frame(len1=as.vector(len1), id=I(names(len1)))

      len2 = tapply(X=det$len*det$len*det$cfdet, INDEX=index, FUN=sum, na.rm=T)
      len2 = data.frame(len2=as.vector(len2), id=I(names(len2)))

      ntot = tapply(X=det$cfdet, INDEX=index, FUN=sum, na.rm=T)
      ntot = data.frame(ntot=as.vector(ntot), id=I(names(ntot)))

      qs = NULL
      qs = merge(mass1, mass2, by=c("id"), sort=F, all=T)
      qs = merge(qs, len1, by=c("id"), sort=F, all=T)
      qs = merge(qs, len2, by=c("id"), sort=F, all=T)

      qs = merge(qs, ntot, by=c("id"), sort=F, all=T)

      qs$mmean = qs$mass1/qs$ntot
      qs$lmean = qs$len1/qs$ntot

      # these are not strictly standard deviations as the denominator is not n-1
      # but the sums being fractional and large .. is a close approximation
      # the "try" is to keep the warnings quiet as NANs are produced.
      qs$msd = try( sqrt( qs$mass2 - (qs$mass1*qs$mass1/qs$ntot) ), silent=T  )
      qs$lsd = try( sqrt( qs$len2 - (qs$len1*qs$len1/qs$ntot)  ), silent=T  )

      qs = qs[, c("id","mmean", "lmean",  "msd", "lsd")]
      set = merge(set, qs, by=c("id"), sort=F, all.x=T, all.y=F, suffixes=c("", paste(".",tx,sep="")) )
    }
    for (i in newvars) set[,i]=NULL # these are temporary vars used to make merges retain correct suffixes

    set$yr = NULL  # dummy var

    save ( set, file=fn, compress=T)
    return( fn  )
  }


  # ----------------------


  if (DS %in% c("set", "set.redo") ) {

    fn = file.path( project.datadirectory("bio.groundfish"), "data", "set.rdata")
    if ( DS=="set" ) {
      load( fn )
      return ( set )
    }
    # this is everything in bio.groundfish just prior to the merging in of habitat data
    # useful for survey.db as the habitat data are brough in separately
    p = bio.groundfish::load.groundfish.environment()

    set = groundfish.db( "set.base" )

    set = lonlat2planar(set, proj.type=p$internal.projection ) # get planar projections of lon/lat in km
    
    grid = spatial_grid(p=p, DS="planar.coords")

    set$plon = grid.internal( set$plon, grid$plons )
    set$plat = grid.internal( set$plat, grid$plats )
    set = set[ which( is.finite( set$plon + set$plat) ), ]

    set$z = set$sdepth
    set$t = set$temp

    set$sdepth = NULL
    set$temp = NULL

    # merge catch
    set = merge (set, groundfish.db( "catchbyspecies" ), by = "id", sort=F, all.x=T, all.y=F )

    # merge determined characteristics
    set = merge (set, groundfish.db( "set.det" ), by = "id", sort=F, all.x=T, all.y=F )

    # strata information
    gst = groundfish.db( DS="gsstratum" )
    w = c( "strat", setdiff( names(gst), names(set)) )
    if ( length(w) > 1 ) set = merge (set, gst[,w], by="strat", all.x=T, all.y=F, sort=F)
    set$area = as.numeric(set$area)

    save ( set, file=fn, compress=F )
    return( fn )

  }

    if (DS %in% c("special.lobster.sampling.redo", "special.lobster.sampling") ) {

    fn = file.path( project.datadirectory("bio.groundfish"), "data", "lobster.special.sampling.rdata")
    if ( DS=="special.lobster.sampling" ) {
      load( fn )
      return ( set )
    }

          require(RODBC)
      connect=odbcConnect( oracle.groundfish.server, uid=oracle.personal.user, pwd=oracle.personal.password, believeNRows=F)
      set =  sqlQuery(connect, " select G.MISSION,G.SETNO,G.SPEC,G.SIZE_CLASS,G.SPECIMEN_ID,G.FLEN,G.FWT, G.FSEX,  G.CLEN, 
                                  max(case when key= 'Spermatophore Presence' then value else NULL END) Sperm_Plug,
                                  max(case when key= 'Abdominal Width' then value else NULL END) Ab_width,
                                  max(case when key= 'Egg Stage' then value else NULL END) Egg_St,
                                  max(case when key= 'Clutch Fullness Rate' then value else NULL END) Clutch_Full
                                  from
                                      (select mission, setno, spec, size_class, specimen_id, flen, fwt, fsex, fmat, fshno, agmat, remarks, age, clen from groundfish.gsdet) G,
                                      (select mission, spec, specimen_id, lv1_observation key, data_value value  from groundfish.gs_lv1_observations
                                          where spec=2550) FC
                                      where 
                                        G.mission = FC.mission (+) and
                                        G.spec = FC.spec and
                                        G.specimen_id = FC.specimen_id (+)
                                          group by G.MISSION,G.SETNO,G.SPEC,G.SIZE_CLASS,G.SPECIMEN_ID,G.FLEN,G.FWT, G.FSEX,  G.CLEN;", as.is=T)
                                odbcClose(connect)
                                save ( set, file=fn, compress=F )
      }
    }


