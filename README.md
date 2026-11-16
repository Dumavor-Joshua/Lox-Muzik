# Lox-Muzik

## Run in VS Code

Open this folder in VS Code and press **F5**. The project starts a local web server and opens the app in the integrated browser. Use this instead of opening `index.html` directly; browsers block the local song files on `file://` pages.

The local server task requires Python.

## Enable shared song uploads

The app stores published songs in Supabase so they can be listed and played by other listeners. In the Supabase project's SQL Editor, run [`supabase/song-library.sql`](./supabase/song-library.sql). Run the updated script when upgrading an existing project: it makes the music bucket private, limits catalog column access, and updates its access policies. Public catalog reads omit creator email addresses; signed-in creators load their own songs through the `get_my_songs()` database function. Song playback uses short-lived signed URLs; artist covers remain public. The upload form's streaming, offline, and device-download permissions are honored by the app. A listener who can stream a song can still capture its audio; these permissions are not DRM.
