set -e
set -x

cat >> "${SDC_CONF}/sdc-security.policy" << EOF
// custom stage library directory
grant codebase "file:///opt/streamsets-datacollector-user-libs/-" {
  permission java.security.AllPermission;
};
EOF