#!/bin/bash

CONFIG_FILE="./settings.conf"

main() {
  backupDB "$PROD_DRUPAL_DB_USER" "$PROD_DRUPAL_DB_PASSWORD" "$PROD_DRUPAL_DB" "$TMP_DIR/prod_drupal.sql"
  backupDB "$PROD_CIVICRM_DB_USER" "$PROD_CIVICRM_DB_PASSWORD" "$PROD_CIVICRM_DB" "$TMP_DIR/prod_civicrm.sql"

  changeDEFINER "$PROD_CIVICRM_DB_USER" "$TEST_CIVICRM_DB_USER" "$TMP_DIR/prod_civicrm.sql"
  changeProdUrlToTestUrl "$TMP_DIR/prod_civicrm.sql"

  restoreDB "$TEST_DRUPAL_DB_USER" "$TEST_DRUPAL_DB_PASSWORD" "$TEST_DRUPAL_DB" "$TMP_DIR/prod_drupal.sql"
  restoreDB "$TEST_CIVICRM_DB_USER" "$TEST_CIVICRM_DB_PASSWORD" "$TEST_CIVICRM_DB" "$TMP_DIR/prod_civicrm.sql"

  copyProductionFilesToTest
  copySettingsPhpFileToTest
  copyTestImageToTest
  clearConfigAndLogAndTemplatesC
  clearCache

  printf "\nDone!\n"
}

backupDB() {
  showStep "Backing up database $3 to $4 ..."
  mysqldump -u "$1" "-p$2" "$3" > "$4"
  checkExitStatus $?  "Cannot backup $3 to $4"
}

restoreDB() {
  showStep "Restoring $4 into $3 ..."
  cat pre.sql "$4" post.sql | mysql -u "$1" "-p$2" "$3" 
  checkExitStatus $?  "Cannot restore $4 into $3"
}

changeDEFINER() {
  showStep "Changing the DEFINER..."
  sed -i "s/DEFINER=\`$1\`@\`localhost\`/DEFINER=\`$2\`@\`localhost\`/g" "$3"
  checkExitStatus $?  "Cannot change DEFINER"
}

changeProdUrlToTestUrl() {
  showStep "Replacing URL's in $1 ..."
  perl replace_url.pl "$1" "$PROD_DOMAIN" "$TEST_DOMAIN" > "$TMP_DIR/temprepl"
  checkExitStatus $?  "Cannot replace url's in $1 via perl script"

  mv "$TMP_DIR/temprepl" "$1"
  checkExitStatus $?  "Cannot mv $TMP_DIR/temprepl to $1"
}

copyProductionFilesToTest() {
  showStep "Clearing test directory..."
  rm -rf "$TEST_PATH/*"
  checkExitStatus $?  "Cannot remove all files in $TEST_PATH"

  showStep "Copying files from production to test..."
  rsync -avzh "$PROD_PATH" "$TEST_PATH"
  checkExitStatus $?  "Cannot copy production files to $TEST_PATH"
}

copySettingsPhpFileToTest() {
  showStep "Copying settings files from temp to test..."
  chmod +w "$TEST_PATH/sites/default"
  copyTempSettingsFileToTest "settings.php" "sites/default"
  copyTempSettingsFileToTest "civicrm.settings.php" "sites/default"
  copyTempSettingsFileToTest ".htaccess" ""
}

copyTestImageToTest() {
  showStep "Copying test image to test..."
  cp "$TEST_IMAGE_SOURCE" "$TEST_IMAGE_TARGET"
}

copyTempSettingsFileToTest() {
  SOURCE_FILE="$TMP_DIR/$1"
  TARGET_PATH="$TEST_PATH/$2"
  TARGET_FILE="$TEST_PATH/$2/$1"

  chmod +w "$TARGET_FILE"
  rm -rf "$TARGET_FILE"
  checkExitStatus $?  "Cannot remove $TARGET_FILE"

  cp "$SOURCE_FILE" "$TARGET_PATH"
  checkExitStatus $?  "Cannot copy $SOURCE_FILE to $TARGET_PATH"
}

clearConfigAndLogAndTemplatesC() {
  showStep "Clearing ConfigAndLog and templates_c in test..."

  rm -rf "$TEST_PATH/sites/default/files/civicrm/ConfigAndLog/*"
  checkExitStatus $?  "Cannot clear ConfigAndLog directiory"

  rm -rf "$TEST_PATH/sites/default/files/civicrm/templates_c/*"
  checkExitStatus $?  "Cannot clear templates_c directiory"
}

clearCache() {
  showStep "Clearing the drupal cache in test..."
  drush cc all --root="$TEST_PATH"
}

checkIfConfigFileExists() {
  if [ ! -f "$CONFIG_FILE" ]
  then
    createConfigFile
  fi
}

createConfigFile() {
  touch "$CONFIG_FILE" 1>/dev/null 2>&1
  checkExitStatus $?  "Cannot create settings file $CONFIG_FILE"

  printf "###################################\n" > $CONFIG_FILE
  printf "# createcivitest configuration file\n" >> $CONFIG_FILE
  printf "###################################\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Show what the script is doing? (0=No, 1=Yes)\n" >> $CONFIG_FILE
  printf "SHOW_STEPS=1\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Where to store temporary files? (backups, copy of settings.php...)\n" >> $CONFIG_FILE
  printf "TMP_DIR=./tmp\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Fill in the production domain (without www, if applicable) and the test domain\n" >> $CONFIG_FILE
  printf "PROD_DOMAIN=example.org\n" >> $CONFIG_FILE
  printf "TEST_DOMAIN=test.example.org\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Fill in the path to the production and test sites\n" >> $CONFIG_FILE
  printf "#   e.g. PROD_PATH=/var/www/mysite.com\n" >> $CONFIG_FILE
  printf "#        TEST_PATH=\/var/www/test.mysite.com\n" >> $CONFIG_FILE
  printf "PROD_PATH=/REPLACE-ME\n" >> $CONFIG_FILE
  printf "TEST_PATH=/REPLACE-ME\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Fill in the drupal production database settings\n" >> $CONFIG_FILE
  printf "PROD_DRUPAL_DB=REPLACE-ME\n" >> $CONFIG_FILE
  printf "PROD_DRUPAL_DB_USER=REPLACE-ME\n" >> $CONFIG_FILE
  printf "PROD_DRUPAL_DB_PASSWORD=REPLACE-ME\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Fill in the CiviCRM production database settings\n" >> $CONFIG_FILE
  printf "PROD_CIVICRM_DB=REPLACE-ME\n" >> $CONFIG_FILE
  printf "PROD_CIVICRM_DB_USER=REPLACE-ME\n" >> $CONFIG_FILE
  printf "PROD_CIVICRM_DB_PASSWORD=REPLACE-ME\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Fill in the drupal test database settings\n" >> $CONFIG_FILE
  printf "TEST_DRUPAL_DB=REPLACE-ME\n" >> $CONFIG_FILE
  printf "TEST_DRUPAL_DB_USER=REPLACE-ME\n" >> $CONFIG_FILE
  printf "TEST_DRUPAL_DB_PASSWORD=REPLACE-ME\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Fill in the CiviCRM test database settings\n" >> $CONFIG_FILE
  printf "TEST_CIVICRM_DB=REPLACE-ME\n" >> $CONFIG_FILE
  printf "TEST_CIVICRM_DB_USER=REPLACE-ME\n" >> $CONFIG_FILE
  printf "TEST_CIVICRM_DB_PASSWORD=REPLACE-ME\n" >> $CONFIG_FILE
  printf "\n" >> $CONFIG_FILE

  printf "# Location of the test image (to clearly see you are on a test site)\n" >> $CONFIG_FILE
  printf "TEST_IMAGE_SOURCE=./tmp/logo.png" 
  printf "TEST_IMAGE_TARGET=ABSOLUTE-PATH-TO-THEME-FOLDER"
  printf "\n" >> $CONFIG_FILE

  showErrorAndQuit "Created the settings file $CONFIG_FILE. Review the settings!"
}

validateSettings() {
  showStep "Checking the production path..."
  assertPathExists "$PROD_PATH"

  showStep "Checking the test path..."
  assertPathExists "$TEST_PATH"

  showStep "Checking production and test paths are different..."
  assertDifferent "$PROD_PATH" "$TEST_PATH"

  showStep "Checking production and test drupal db names are different..."
  assertDifferent "$PROD_DRUPAL_DB" "$TEST_DRUPAL_DB"

  showStep "Checking production and test CiviCRM db names are different..."
  assertDifferent "$PROD_CIVICRM_DB" "$TEST_CIVICRM_DB"

  showStep "Checking temp directory..."
  createTmpDirIfNeeded

  showStep "Checking test settings.php / civicrm.settings.php"
  checkTestSettingsPhpFiles
}

createTmpDirIfNeeded() {
  if [ ! -d "$TMP_DIR" ]
  then
    mkdir "$TMP_DIR"
    checkExitStatus $?  "Cannot create temp dir: $TMP_DIR"
  fi
}

checkTestSettingsPhpFiles() {
  assertSettingsFileInTemp "settings.php"
  assertSettingsFileInTemp "civicrm.settings.php"
  assertSettingsFileInTemp ".htaccess"
}

assertSettingsFileInTemp() {
  if [ ! -f "$TMP_DIR/$1" ]
  then
    showErrorAndQuit "The directory $TMP_DIR must contain the $1 file for the TEST site with the correct settings for TEST -- IMPORTANT --"
  fi
}

assertPathExists() {
  if [ ! -d "$1" ]
  then
    showErrorAndQuit "The directory $1 does not exist"
  fi
}

assertDifferent() {
  if [ "$1" = "$2" ]
  then
    showErrorAndQuit "$1 and $2 should be different"
  fi
}

readConfigFile() {
  source $CONFIG_FILE
  checkExitStatus $?  "Cannot open $CONFIG_FILE"
}

checkExitStatus() {
  if [ $1 -ne 0 ]
  then
    showErrorAndQuit "$2"
  fi
}

showErrorAndQuit() {
  >&2 printf "ERROR: $1\n"
  exit 1
}

showStep() {
  if [ $SHOW_STEPS -gt 0 ]
  then
    printf "$1\n"
  fi
}


checkIfConfigFileExists
readConfigFile
validateSettings
main

