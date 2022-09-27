<?php
declare(strict_types=1);

function getUrlProvider(string $url): string {
  return $url;
}

function getUrlTemplated(string $url): string {
  if (preg_match("/^(.*&BBOX=)[0-9A-F,%.]+/", $url, $m) > 0) {
    return $m[1] . '{bbox}';
  }
  if (preg_match("/^(.*\/)[0-9]+\/[0-9]+\/[0-9]+(\.[^.\/]+)$/", $url, $m) > 0) {
    return $m[1] . '{z}/{x}/{y}' . $m[2];
  }
  return $url;
}

function getUrlDomain(string $url): string {
  if (preg_match("/^[^:]*:\/\/([^\/?]*)/", $url, $m) <= 0) {
    return '';
  }
  return $m[1];
}

function parseCurlToConfig(string $curl): array {
  $body = '';
  if (preg_match_all("/--data-raw '([^']*)'/", $curl, $m) > 0) {
    $body = $m[1][0];
  }

  $headers = [];
  if (preg_match_all("/-H *'([^':]*): ([^']*)'/", $curl, $m) > 0) {
    for ($i=0; $i < sizeof($m[0]); $i++) {
      $key = $m[1][$i];
      if (strtoupper($key) !== 'CONTENT-LENGTH') {
        $headers[$key] = $m[2][$i];
      }
    }
  }

  if (preg_match("/^curl *'([^']*)'/", $curl, $m) <= 0) {
    return [];
  }
  $url = $m[1];

  unset($headers['xoltile']);
  $domain = getUrlDomain($url);
  $templated = getUrlTemplated($url);

  $ret = [
    $domain => $headers,
    'templated' => $templated
  ];
  if ($templated !== $domain) {
    $ret[$templated] = $body;
  }

  return $ret;
}

function appendNonce(array &$headers) {
  $start = parseAuthorizationTime($headers['authorization']);
  $diff = (int)(microtime(true) * 1000) - $start * 1000;
  $nonce = base64_encode(sprintf('%b', $diff));
  $headers['xoltile'] = $nonce;
}

function parseHeaders(array $headers): array {
  $parsed = [];
  foreach ($headers as $i => $line) {
    $f = explode(':', $line, 2);
    if (isset($f[1])) {
      $k = strtoupper(trim($f[0]));
      $parsed[$k] = trim($f[1]);
    } else {
      $parsed['http_response_line'] = $line;
      if (preg_match("~^HTTP/[0-9\.]+\s+([0-9]+)\s+(.*)$~", $line, $out)) {
        $parsed['http_response_code'] = asInt($out[1]);
        $parsed['http_response_message'] = $out[2];
      }
    }
  }
  return $parsed;
}

function asInt(string $str): int {
  if (1 === sscanf($str, '%d%s', $int, $left))
    return $int;
  return -1;
}

function htmlTime(int $second): string {
  return gmdate('D, d M Y H:i:s T', $second);
}

function parseAuthorizationTime(string $auth): int {
  if (1 !== preg_match('/^Bearer [^.]*\.([^.]*)/', $auth, $matches)) {
    return -1;
  }
  $str = base64_decode($matches[1]);
  if (FALSE === $str) {
    return -1;
  }
  $obj = json_decode($str, true);
  if (!isset($obj["iat"])) {
    return -1;
  }
  $time = $obj["iat"];
  if (!is_int($time)) {
    return -1;
  }
  return $time;
}
