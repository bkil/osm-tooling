<?php
declare(strict_types=1);

include_once 'test_include.php';
include_once '../src/include.php';

function test_getUrlTemplated(): bool {
  return testFun('getUrlTemplated', [
    "http://localhost/1/2/3.txt" =>
      'http://localhost/{z}/{x}/{y}.txt',
    "https://localhost/a?q=1&BBOX=1.2%2C3" =>
      'https://localhost/a?q=1&BBOX={bbox}',
  ]);
}

function test_parseCurlToConfigChrome(): bool {
  return testFun('parseCurlToConfigStr', [
    "curl 'https://localhost/a?q=1&BBOX=1.2%2C3' \\\n  -X 'POST' \\\n  -H 'xoltile: 0' \\\n  -H 'User-Agent: 42' \\\n  -H 'authorization: Bearer 1.2.3' \\\n  --data-raw 'body'" =>
      '{"localhost":{"User-Agent":"42","authorization":"Bearer 1.2.3"},"templated":"https:\/\/localhost\/a?q=1&BBOX={bbox}","https:\/\/localhost\/a?q=1&BBOX={bbox}":"body"}',
  ]);
}

function test_parseCurlToConfigFirefox(): bool {
  return testFun('parseCurlToConfigStr', [
    "curl 'https://localhost/a?q=1&BBOX=1.2%2C3' -X 'POST' -H 'xoltile: 0' -H 'User-Agent: 42' -H 'authorization: Bearer 1.2.3' --data-raw 'body'" =>
      '{"localhost":{"User-Agent":"42","authorization":"Bearer 1.2.3"},"templated":"https:\/\/localhost\/a?q=1&BBOX={bbox}","https:\/\/localhost\/a?q=1&BBOX={bbox}":"body"}',
  ]);
}

function parseCurlToConfigStr(string $str): string {
  return json_encode(parseCurlToConfig($str));
}

function test_parseAuthorizationTime(): bool {
  return testFun('parseAuthorizationTimeStr', [
    "Bearer e30=.eyJpYXQiOjEyMzQ1Njc4OTB9." =>
      '1234567890',
  ]);
}

function parseAuthorizationTimeStr(string $auth): string {
  $time = parseAuthorizationTime($auth);
  if (-1 === $time) {
    return "";
  }
  return strval($time);
}

function test_getUrlDomain(): bool {
  return testFun('getUrlDomain', [
    "http://localhost:1234/?b=1&k=v#hash" => 'localhost:1234',
  ]);
}

function test_asInt(): bool {
  return testFun('asIntStr', [
    "0" => '0',
    "42" => '42',
    "x" => '-1',
    "x42" => '-1',
    "42x" => '-1',
  ]);
}

function asIntStr(string $str): string {
  return '' . asInt($str);
}

function test_htmlTime(): bool {
  return testFun('htmlTimeStr', [
    "946782245" => 'Sun, 02 Jan 2000 03:04:05 GMT',
  ]);
}

function htmlTimeStr($s) {
  return htmlTime(asInt($s));
}

function test_parseHeaders(): bool {
  return testFun('parseHeadersStr', [
    '["HTTP/1.0 200 OK", "x: y", "hi: 42"]' =>
      '{"http_response_line":"HTTP\/1.0 200 OK","http_response_code":200,"http_response_message":"OK","X":"y","HI":"42"}',
  ]);
}

function parseHeadersStr($s) {
  return json_encode(parseHeaders(json_decode($s, true)));
}

exit(
  test_parseCurlToConfigChrome() &
  test_parseCurlToConfigFirefox() &
  test_getUrlDomain() &
  test_parseAuthorizationTime() &
  test_getUrlTemplated() &
  test_asInt() &
  test_htmlTime() &
  test_parseHeaders()
  ? 0 : 1);
