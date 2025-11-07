## 0.4.6

- fix: parse EXT-X-MAP failed

## 0.4.5

- fix: m3u8 bytes-range parse

## 0.4.4

- fix: default parser cache error when concurrent downloading

## 0.4.3

- fix: mp4 cache error when concurrent downloading

## 0.4.2

- fix: mp4 download failed on iOS when content-length return error value

## 0.4.1

- feat: add support for local video server.
- fix: segment in m3u8 file which start with "/", it will cause save directory error.

## 0.4.0

- feat: add `VideoCaching.isCached` to check if a video is cached

## 0.3.11

- fix: SocketException Write failed

## 0.3.10

- feat: support storageSizeInBytes (pr #20 from cenumi)

## 0.3.9

- fix: parse EXT-X-BYTERANGE failed

## 0.3.8

- doc: Update README

## 0.3.7

- feat: Add `HttpClientBuilder` abstract class for flexible `HttpClient` instantiation and configuration

## 0.3.6

- fix: write mode error (FileMode)

## 0.3.5

- fix: The concurrent download limit is not effective
- doc: Improve code comments
- doc: Update README

## 0.3.4

- chore: Unified HLS resolution extraction logic for pre-cache and video playback (pr #13 from JagaranMaharjan)
- chore: add support for custom url match - UrlMatcher
- fix: remove carriage returns (%0D) in url

## 0.3.3

- fix: head request with header 'host' and 'range' causes an error (pr #10 from vinicius-felip)

## 0.3.2

- fix: request headers for precache and download doesn't match

## 0.3.1

- fix: change `CUSTOM_CACHE_ID` to `Custom-Cache-ID`

## 0.3.0

- feat: add function to remove cache by url or directory path
- chore (m3u8/preCache): add additional params to return in stream controller (pr #9 by
  JagaranMaharjan)
- feat: add func for parse HlsMasterPlaylist
- chore: add request header support for precache and download
- feat: add request headers support for custom cache id
- fix: max Concurrent Downloads limit does not take effect

## 0.2.0

- feat: persistent video content-length
- feat: add progress track for precache video

## 0.1.10

- fixed: compatible with multiple types of players (media_kit, flick_player, pod_player)
- fixed: handle socket exception

## 0.1.9

- fixed: milti-resolution m3u8 parse error

## 0.1.8

- fixed: toLocalUrl may parse error in some cases
- fixed: write error: PathNotFoundException: Cannot open file (#3)

## 0.1.7

- fixed: parse and download mp4 failed on iOS

## 0.1.6

- fixed: video pre-caching concurrent error handling
- fixed: url with query string not work

## 0.1.5

- fixed: isolate log print failed
- fixed: m3u8 encrypted key saved in error directory
- fixed: preview video with error type
- fixed: url with query string not work

## 0.1.4

- fixed: m3u8 parse EXT-X-KEY failed

## 0.1.3

- feat: LruCacheSingleton export more function

## 0.1.2

- feat: add support for max cache size of memory and storage

## 0.1.1

- update README.md and improve scores.

## 0.1.0

- Play and cache video when playing, support m3u8 and mp4 formats.
