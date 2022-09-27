<?php
declare(strict_types=1);
include_once 'include.php';

function main() {
  header_remove('X-Powered-By');
  if (isset($_REQUEST['u'])) {
    serve($_REQUEST['u']);
  } else {
    setup();
  }
}

function setup() {
  if (isset($_POST['c'])) {
    setupSubmit($_POST['c']);
  } else {
    setupForm();
  }
}

function setupForm(string $curl = '') {
  header('Content-type: text/html');
  echo
    '<!DOCTYPE html><html><head><title>curl command line</title></head><body>' .
    setupFormBody($curl) .
    '</body></html>';
}

function setupFormBody(string $curl = ''): string {
  return
    '<style>textarea { display: block; }</style>' .
    '<form method=post><label>Please copy curl command line<textarea name=c autofocus cols=40 rows=30>' .
    $curl .
    '</textarea></label>' .
    '<input type=submit>' .
    '</form>';
}

function setupSubmit(string $curl) {
  $config = parseCurlToConfig($curl);
  if (!isset($config['templated'])) {
    header('HTTP/1.0 400 Parse error');
    setupForm($curl);
    exit();
  }
  $templated = $config['templated'];
  unset($config['templated']);

  if (!updateConfig($config)) {
    header('HTTP/1.0 500 Config save error');
    setupForm($curl);
    exit();
  }

  header('Content-type: text/html');
  $templated = urlencode($templated);
  $templated = str_replace('%7B', '{', $templated);
  $templated = str_replace('%7D', '}', $templated);
  $url = 'http://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'] . '?u=' . $templated;
  echo
    '<!DOCTYPE html><html><head><title>OK</title></head><body>' .
    '<a href="' . $url . '" rel=noopener style="cursor:default" onclick="return false">' .
    htmlspecialchars($url) .
    '</a>' .
    setupFormBody('') .
    '</body></html>';
}

function updateConfig(array $newConfig): bool {
  if (false === $f = fopen(getConfigName(), 'c+')) {
    return false;
  }
  if (!flock($f, LOCK_EX)) {
    fclose($f);
    return false;
  }

  $lockDir = getConfigName() . '.lock';
  if (!@mkdir($lockDir)) {
    fclose($f);
    return false;
  }

  $config = $newConfig + readConfig();
  if (false === $str = json_encode($config)) {
    rmdir($lockDir);
    flock($f, LOCK_UN);
    fclose($f);
    return false;
  }

  if (false === $tmp = tempnam('.', 'config.tmp.json.')) {
    rmdir($lockDir);
    flock($f, LOCK_UN);
    fclose($f);
    return false;
  }

  $str = '<?php // ' . $str;

  if (strlen($str) !== file_put_contents($tmp, $str)) {
    @unlink($tmp);
    rmdir($lockDir);
    flock($f, LOCK_UN);
    fclose($f);
    return false;
  }

  if (!rename($tmp, getConfigName())) {
    unlink($tmp);
    rmdir($lockDir);
    flock($f, LOCK_UN);
    fclose($f);
    return false;
  }

  rmdir($lockDir);
  flock($f, LOCK_UN);
  fclose($f);
  return true;
}

function serve(string $requestedUri) {
  verifyCaching();

  if (!$config = readConfig()) {
    exitFailure('403 Setup needed', 'config file missing');
  }

  $domain = getUrlDomain($requestedUri);
  if (!isset($config[$domain])) {
    exitFailure('403 Domain setup needed', $domain);
  }
  $headers = $config[$domain];

  $templated = getUrlTemplated($requestedUri);
  if (isset($config[$templated])) {
    $body = $config[$templated];
  } else {
    $body = '';
  }

  appendNonce($headers);
  $stringHeaders = [];
  foreach ($headers as $k => $v) {
    $stringHeaders[] = $k . ': ' . $v;
  }
  $headers = [];

  $stream = openForDownload(getUrlProvider($requestedUri), $stringHeaders, $body);
  downloadPassthru($stream);
}

function getConfigName(): string {
  return 'secret-config.json.php';
}

function readConfig(): array {
  if (!file_exists(getConfigName())) {
    return [];
  }
  if (false === $str = file_get_contents(getConfigName())) {
    return [];
  }
  $str = preg_replace('/^[^\/]*\/\/ */', '', $str);
  if (null === $obj = json_decode($str, true)) {
    return [];
  }

  return $obj;
}

function verifyCaching() {
  if (isset($_SERVER['HTTP_IF_MODIFIED_SINCE']) || isset($_SERVER['HTTP_IF_NONE_MATCH'])) {
    exitFailure('304 Not Modified');
  }
}

function openForDownload(string $url, array $headers, string $body = '') {
  ini_set('default_socket_timeout', '20');
  ini_set('user_agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)
Chrome/78.0.3904.108 Safari/537.36');

  $posted = [
    'method' => 'POST',
    'content' => $body,
  ];

  $context = stream_context_create(
    [
      'http' => $posted + [
        'protocol_version' => 1.1,
        'header' => $headers + [
          'Connection: close',
          'Content-Length: ' . strlen($body),
          ],
      ],
      'tcp' => [
        'tcp_nodelay' => true,
      ]
    ]);
  $stream = @fopen($url, 'r', false, $context);

  if (!isset($http_response_header[0])) {
    exitFailure('504 Gateway Timeout', 'Unknown failure');
  }

  $parsed = parseHeaders($http_response_header);

  if (!$stream) {
    $errorCode = isset($parsed['http_response_code']) ? $parsed['http_response_code'] : -1;
    $errorMessage = isset($parsed['http_response_message']) ? $parsed['http_response_message'] : '';
    if (($errorCode >= 400) && ($errorCode <= 599)) {
      $statusLine = $errorCode . ' ' . $errorMessage;
    } else {
      $statusLine = '502 Bad Gateway';
    }
    exitFailure($statusLine, 'Download failed');
  }

  $contentLength = isset($parsed['CONTENT-LENGTH']) ? asInt($parsed['CONTENT-LENGTH']) : -1;
  if ($contentLength >= 0) {
    header('Content-Length: ' . $contentLength);
  }

  $mime = 'image/jpeg';
  if (isset($parsed['CONTENT-TYPE'])) {
    $mime = $parsed['CONTENT-TYPE'];
  }
  header('Content-Type: ' . $mime);
  return $stream;
}

function downloadPassthru($stream) {
  $timeout = 3600 * 24 * 21;
  header("Cache-Control: public, max-age=$timeout, stale-while-revalidate=$timeout, s-maxage=$timeout");
  header('Content-Transfer-Encoding: binary');
  $time = htmlTime($_SERVER['REQUEST_TIME']);
  header('Date: ' . $time);
  header('Last-Modified: ' . $time);
  header('Expires: ' . htmlTime($_SERVER['REQUEST_TIME'] + $timeout));
  header('ETag: "42"');
  ob_end_clean();

  fpassthru($stream);
  fclose($stream);
}

function exitFailure(string $statusLine, string $body = ''): void {
  header('HTTP/1.0 ' . $statusLine);
  if ($body) {
    header('Content-Type: text/html');
    $msg = $body . ' (' . $statusLine . ')';
    echo '<!DOCTYPE html><html><head><meta charset="utf-8" /><title>' . $msg . '</title>
</head>';
    echo '<p><b> </b> </p><p><b> </b> ' . $msg . '</p><p><b> </b> </p></body></html>';
  }
  exit();
}

main();
