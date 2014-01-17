#!/bin/bash -ex
# requirements:
# - ~/.sonatype-curl that consists of user = USER:PASS
# - ~/.m2/settings.xml with credentials for sonatype
    # <server>
    #   <id>private-repo</id>
    #   <username>jenkinside</username>
    #   <password></password>
    # </server>
# - ~/.ivy2/.credentials-private-repo as follows:
    # realm=Artifactory Realm
    # host=private-repo.typesafe.com
    # user=jenkinside
    # password=

# defaults for jenkins params
   SCALA_VER_BASE=${SCALA_VER_BASE-"2.11.0"}
SCALA_VER_SUFFIX=${SCALA_VER_SUFFIX-"-M8"}
          XML_VER=${XML_VER-"1.0.0-RC7"}
      PARSERS_VER=${PARSERS_VER-"1.0.0-RC5"}
CONTINUATIONS_VER=${CONTINUATIONS_VER-"1.0.0-RC3"}
        SWING_VER=${SWING_VER-"1.0.0-RC2"}
      PARTEST_VER=${PARTEST_VER-"1.0.0-RC8"}
PARTEST_IFACE_VER=${PARTEST_IFACE_VER-"0.2"}
   SCALACHECK_VER=${SCALACHECK_VER-"1.11.2"}

            SCALA_REF=${SCALA_REF-"master"}
              XML_REF=${XML_REF-"v$XML_VER"}
          PARSERS_REF=${PARSERS_REF-"v$PARSERS_VER"}
    CONTINUATIONS_REF=${CONTINUATIONS_REF-"v$CONTINUATIONS_VER"}
            SWING_REF=${SWING_REF-"v$SWING_VER"}
          PARTEST_REF=${PARTEST_REF-"v$PARTEST_VER"}
    PARTEST_IFACE_REF=${PARTEST_IFACE_REF-"v$PARTEST_IFACE_VER"}
       SCALACHECK_REF=${SCALACHECK_REF-"$SCALACHECK_VER"}


scriptsDir="$( cd "$( dirname "$0" )/.." && pwd )"
. $scriptsDir/common
. $scriptsDir/pr-scala-common

#parse_properties versions.properties


# repo used to publish "locker" scala to (to start the bootstrap)
# TODO: change to dedicated repo
stagingCred="private-repo"
stagingRepo="http://private-repo.typesafe.com/typesafe/scala-release-temp/"
publishTask=publish-signed #publish-local

#####

SCALA_VER="$SCALA_VERBASE$SCALA_VER_SUFFIX"

baseDir=`pwd` # ~/git/pr-scala/scratch #

stApi="https://oss.sonatype.org/service/local/"

function st_curl(){
  curl -H "accept: application/json" -K ~/.sonatype-curl -s -o - $@
}

function st_stagingRepoMostRecent() {
 st_curl "$stApi/staging/profile_repositories" | jq '.data[] | select(.profileName == "org.scala-lang") | .repositoryURI' | tr -d \" | tail -n1
}


update() {
  [[ -d $baseDir ]] || mkdir -p $baseDir
  cd $baseDir
  getOrUpdate $baseDir/$2 "https://github.com/$1/$2.git" $3
  cd $2
}

publishModules() {
  # test and publish to sonatype, assuming you have ~/.sbt/0.13/sonatype.sbt and ~/.sbt/0.13/plugin/gpg.sbt
  update scala scala-xml "$XML_REF"
  sbt 'set version := "'$XML_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      clean test publish-signed

  update scala scala-parser-combinators "$PARSERS_REF"
  sbt 'set version := "'$PARSERS_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      clean test publish-signed

  update rickynils scalacheck $SCALACHECK_REF
  sbt 'set version := "'$SCALACHECK_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      'set every scalaBinaryVersion := "'$SCALA_VER'"' \
      'set VersionKeys.scalaParserCombinatorsVersion := "'$PARSERS_VER'"' \
      clean test publish-local

  update scala scala-partest "$PARTEST_REF"
  sbt 'set version :="'$PARTEST_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      'set VersionKeys.scalaXmlVersion := "'$XML_VER'"' \
      'set VersionKeys.scalaCheckVersion := "'$SCALACHECK_VER'"' \
      clean test publish-signed

  update scala scala-partest-interface "$PARTEST_IFACE_REF"
  sbt 'set version :="'$PARTEST_IFACE_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      clean test publish-signed

  update scala scala-continuations $CONTINUATIONS_REF
  sbt 'set every version := "'$CONTINUATIONS_VER'"' \
      'set every scalaVersion := "'$SCALA_VER'"' \
      clean test publish-signed


  update scala scala-swing "$SWING_REF"
  sbt 'set version := "'$SWING_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      clean test publish-signed

}

# Duplicated because I cannot for the life of me figure out how to pass in these quoted sbt commands as args to a bash function
publishModulesPrivate() {
  resolver='"scala-release-temp" at "'$stagingRepo'"'

  # test and publish to sonatype, assuming you have ~/.sbt/0.13/sonatype.sbt and ~/.sbt/0.13/plugin/gpg.sbt
  update scala scala-xml "$XML_REF"
  sbt 'set version := "'$XML_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
        "set resolvers += $resolver"\
        "set publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test publish

  update scala scala-parser-combinators "$PARSERS_REF"
  sbt 'set version := "'$PARSERS_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
        "set resolvers += $resolver"\
        "set publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test publish

  update rickynils scalacheck $SCALACHECK_REF
  sbt 'set version := "'$SCALACHECK_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      'set every scalaBinaryVersion := "'$SCALA_VER'"' \
      'set VersionKeys.scalaParserCombinatorsVersion := "'$PARSERS_VER'"' \
        "set resolvers += $resolver"\
        "set publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test publish

  update scala scala-partest "$PARTEST_REF"
  sbt 'set version :="'$PARTEST_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
      'set VersionKeys.scalaXmlVersion := "'$XML_VER'"' \
      'set VersionKeys.scalaCheckVersion := "'$SCALACHECK_VER'"' \
        "set resolvers += $resolver"\
        "set publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test publish

  update scala scala-partest-interface "$PARTEST_IFACE_REF"
  sbt 'set version :="'$PARTEST_IFACE_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
        "set resolvers += $resolver"\
        "set publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test $1

  update scala scala-continuations $CONTINUATIONS_REF
  sbt 'set every version := "'$CONTINUATIONS_VER'"' \
      'set every scalaVersion := "'$SCALA_VER'"' \
        "set resolvers += $resolver"\
        "set every publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test publish


  update scala scala-swing "$SWING_REF"
  sbt 'set version := "'$SWING_VER'"' \
      'set scalaVersion := "'$SCALA_VER'"' \
        "set resolvers += $resolver"\
        "set publishTo := Some($resolver)"\
        'set credentials += Credentials(Path.userHome / ".ivy2" / ".credentials-private-repo")'\
      clean test publish

}

update scala scala $SCALA_REF

# publish core so that we can build modules with this version of Scala and publish them locally
# must publish under $SCALA_VER so that the modules will depend on this (binary) version of Scala
# publish more than just core: partest needs scalap
ant -Dmaven.version.number=$SCALA_VER\
    -Dremote.snapshot.repository=NOPE\
    -Drepository.credentials.id=$stagingCred\
    -Dremote.release.repository=$stagingRepo\
    -Dscalac.args.optimise=-optimise\
    -Ddocs.skip=1\
    -Dlocker.skip=1\
    publish


# build, test and publish modules with this core
# publish to our internal repo (so we can resolve the modules in the scala build below)
publishModulesPrivate

# TODO: close all open staging repos so that we can be reaonably sure the only open one we see after publishing below is ours
# the ant call will create a new one

# Rebuild Scala with these modules so that all binary versions are consistent.
# Update versions.properties to new modules.
# Sanity check: make sure the Scala test suite passes / docs can be generated with these modules.
# don't skip locker (-Dlocker.skip=1\), or stability will fail
# stage to sonatype, along with all modules
cd $baseDir/scala
git clean -fxd
ant -Dstarr.version=$SCALA_VER\
    -Dextra.repo.url=$stagingRepo\
    -Dmaven.version.suffix=$SCALA_VER_SUFFIX\
    -Dscala.binary.version=$SCALA_VER\
    -Dpartest.version.number=$PARTEST_VER\
    -Dscala-xml.version.number=$XML_VER\
    -Dscala-parser-combinators.version.number=$PARSERS_VER\
    -Dscala-continuations.version.number=$CONTINUATIONS_VER\
    -Dscala-swing.version.number=$SWING_VER\
    -Dscalacheck.version.number=$SCALACHECK_VER\
    -Dupdate.versions=1\
    -Dscalac.args.optimise=-optimise\
    nightly $publishTask

# publish to sonatype
publishModules

echo "Published to sonatype staging repo $(st_stagingRepoMostRecent), which may now be closed."
echo "Update versions.properties, tag as $vSCALA_VER, and run scala-release-2.11.x."

# git commit versions.properties -m"Bump versions.properties for $SCALA_VER."
# TODO: push to github

# tag "v$SCALA_VER" "Scala v$SCALA_VER"

# used when testing scalacheck integration with partest, while it's in staging repo before releasing it
#     'set resolvers += "scalacheck staging" at "http://oss.sonatype.org/content/repositories/orgscalacheck-1010/"' \
# in ant: ()
#     -Dextra.repo.url=http://oss.sonatype.org/content/repositories/orgscalacheck-1010/\
