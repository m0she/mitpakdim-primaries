<?php
$VERSION = 0;
$REVISION = 1;

$MIN_USER = 1001;
$MAX_USER = 9999;

$user = $_REQUEST['user'];
$value = hexdec($user);

$verify = bcmod($value, 946384521);

$userid = intval($verify / 10000);
$version = intval(($verify / 100) % 100);
$revision = intval($verify % 100);

if (($userid >= $MIN_USER) &&
     ($userid <= $MAX_USER) &&
     (($version < $VERSION) || (($version == $VERSION) && ($revision <= $REVISION)))) {
    $_SESSION['userid'] = $userid;
    #header('Location: base.php');
    readfile('base.html');
} else {
    echo "<h2>Bad login</h2>";
}

?>
