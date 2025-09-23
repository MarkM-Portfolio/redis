@Library('quickstart') _

qs {
    nodejsVersion = 'nodejs14'
    plugin = 'loopback'
    deployOwner = 'connections'
    deployBranch = 'master'    
    dockerRegistry = 'connections-docker.artifactory.cwp.pnp-hcl.com'
    dockerImageName = 'middleware-redis'
    deployScript = 'scripts/pinkserver/pinkserver_redeploy.sh'
    slackNotify = [teamDomain: 'ibm-ics', token: 'FTjxUWOxoGyocYqU80ojMg9m']
    DEBUG_BUILD_ALL = false
    beforeBuildScript = 'scripts/npm/npm_install_clean.sh'
    buildScript = 'scripts/npm_build.sh'
}
