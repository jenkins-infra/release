#
# Environment definition for the packaging process
#

# where to put binary files
export WARDIR=${BASE_BIN_DIR}/war${RELEASELINE}
export MSIDIR=${BASE_BIN_DIR}/windows${RELEASELINE}
export DEBDIR=${BASE_BIN_DIR}/debian${RELEASELINE}
export RPMDIR=${BASE_BIN_DIR}/rpm${RELEASELINE}

# where to put repository index and other web contents
export RPM_WEBDIR=${BASE_PKG_DIR}/rpm${RELEASELINE}
export MSI_WEBDIR=${BASE_PKG_DIR}/windows${RELEASELINE}
export DEB_WEBDIR=${BASE_PKG_DIR}/debian${RELEASELINE}

# URL to the aforementioned webdir.
WEBSERVER=https://pkg.jenkins.io
export RPM_URL=${WEBSERVER}/rpm${RELEASELINE}
export DEB_URL=${WEBSERVER}/debian${RELEASELINE}
