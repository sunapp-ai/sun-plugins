# SUN MCP tool contracts

All fifteen tools require a connected SUN account. They return a text summary
and the same data in `structuredContent`. Error results use this shape:

```json
{
  "error": {
    "code": "string",
    "message": "string"
  }
}
```

Authentication failures are tool errors rather than transport errors. The MCP
response can still use HTTP 200 while `isError` is true and
`_meta["mcp/www_authenticate"]` asks ChatGPT to connect the account. Every other
error carries no `_meta`: it is not a reason to reconnect. Do not branch on HTTP
status codes in a skill.

| Tool                        | Scope             | Annotations                             |
| --------------------------- | ----------------- | --------------------------------------- |
| `create_audio_course`       | `courses:write`   | writes, open-world                      |
| `create_meditation`         | `courses:write`   | writes, open-world                      |
| `create_story`              | `courses:write`   | writes, open-world                      |
| `create_song`               | `courses:write`   | writes, open-world                      |
| `create_source_file_upload` | `courses:write`   | writes                                  |
| `get_course_status`         | `courses:read`    | read-only                               |
| `get_course`                | `courses:read`    | read-only                               |
| `get_source_file_status`    | `courses:read`    | read-only                               |
| `whoami`                    | `courses:read`    | read-only                               |
| `get_credit_balance`        | `courses:read`    | read-only                               |
| `list_voices`               | `courses:read`    | read-only                               |
| `list_characters`           | `courses:read`    | read-only                               |
| `schedule_briefing`         | `briefings:write` | writes, open-world (sends pushes later) |
| `list_scheduled_briefings`  | `briefings:read`  | read-only                               |
| `cancel_scheduled_briefing` | `briefings:write` | destructive                             |

`create_song` is listed only while songs are enabled on the server; without it
there are fourteen tools.

A connection made before the briefing scopes existed has only the course
scopes. Its first briefing call returns `insufficient_scope`, and the
re-authorization asks for all four scopes at once.

## `create_audio_course`

Starts one asynchronous generation.

Inputs:

- `prompt` (string, required): 1 to 4,000 characters.
- `duration_minutes` (integer, optional): 5 to 120; defaults to 30.
- `files` (array, optional): up to 20 file references ChatGPT supplies for
  attachments (`download_url` and `file_id` required, `mime_type` and
  `file_name` optional). The course is built from them and opens with a short
  spoken intro about them.
- `file_ids` (array of up to 20 unique strings, optional): `file_id` values
  returned by an upload made with `create_source_file_upload` (Codex and other
  clients that hold a file only as a local path). `files` and `file_ids` can be
  combined; together they are limited to 20 files.
- `voice_id` (string, optional): a `voice_id` from `list_voices`. The course
  then follows that voice's language.
- `character_ids` (array of 1 to 2 unique strings, optional): ids from
  `list_characters`. One narrates alone; two share every lecture and the first
  leads. Cannot be combined with `voice_id`.
- `course_language` (`en` | `es` | `hi` | `zh`, optional): pass only when the
  user explicitly asks for a language. With a voice it must match the voice's
  language; a character's own language never sets it.

Result:

```json
{
  "job_id": "string",
  "course_id": "string",
  "status": "PENDING",
  "status_url": "/v1/public/courses/<job_id>/status",
  "result_url": "/v1/public/courses/<job_id>",
  "listen_url": "https://sunapp.ai/item/<course_id>",
  "billing": {
    "estimated_credits": 600,
    "estimated_minutes": 10,
    "waived": false,
    "waived_reason": null
  },
  "files": [{ "file_id": "string", "file_name": "string", "status": "receiving" }]
}
```

`billing` is the generation's expected cost in the user's SUN credits (60
credits per minute). It is charged by the actual length once the generation
finishes, and nothing is charged if it fails. `waived` is true when this
generation costs nothing: `waived_reason` is `first_generation` for the
account's free first generation, or `exempt` for an account that is never
charged. The tool's text already states the cost; pass it on as written.
`billing` can be null, in which case say nothing about cost.

`files` is present only when attachments or `file_ids` were passed; an
uploaded file is listed by its `file_id` alone. The result returns
immediately. Preserve `job_id`; the other course tools use it as their
identifier. `listen_url` is the page where the user listens; give it to them as
it is rather than building a URL.

Errors refused before anything is created (no credits used):

| `code`                              | Meaning                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `voice_not_available`               | `voice_id` is not in `list_voices` for this user (someone else's voice, deleted, or made up).                             |
| `voice_language_mismatch`           | `course_language` differs from the chosen voice's language.                                                               |
| `voice_catalog_unavailable`         | The voice list could not be read; try again shortly.                                                                      |
| `voice_and_characters`              | Both `voice_id` and `character_ids` were passed.                                                                          |
| `invalid_character_ids`             | Duplicate or blank character ids.                                                                                         |
| `invalid_file_reference`            | A `files` entry is not a ChatGPT file reference, a `file_ids` entry is not a `file_id`, or more than 20 files were given. |
| `unsupported_character_combination` | With files, the two characters' voices cannot be combined. Pick another character or drop the files.                      |
| `voice_not_supported_with_files`    | The chosen voice cannot narrate a course built from files.                                                                |

Relay the returned `message` as it is; do not retry with the same arguments.

Credit and rate refusals, returned by every create tool (`create_audio_course`,
`create_meditation`, `create_story`, `create_song`) before anything is created
(no credits used):

| `code`                 | Meaning                                                                                                                                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `no_entitlement`       | The account has no credits available for this generation. Includes `info_url`.                                                                                                                                        |
| `insufficient_credits` | The balance does not cover the requested length. Includes `requested_minutes` and `max_affordable_minutes`; when the latter is at least 1, a version up to that length can be generated instead. Includes `info_url`. |
| `too_many_requests`    | Too many generations were started in the last minute. Includes `retry_after_seconds`.                                                                                                                                 |
| `billing_unavailable`  | The balance could not be checked right now; try again shortly.                                                                                                                                                        |

The first credit refusal for an account also carries `first_notice: true`, and
its message opens with a line explaining that SUN uses the account's credits.
Relay the `message` as it is and stop. Do not retry, do not recommend buying,
upgrading or subscribing, and do not state prices or plans. `info_url` is an
informational page about credits; share it only as given.

## `create_meditation`

Starts one asynchronous guided meditation, played as one continuous session.
For learning about meditation (its science, history or benefits) use
`create_audio_course`.

Inputs:

- `request` (string, required): 1 to 4,000 characters; the user's own words,
  including any breathing pattern or reason they gave.
- `duration_minutes` (integer, optional): 3 to 30; defaults to 10.
- `purpose` (`calm` | `sleep` | `focus` | `body_scan`, optional): only when the
  user said what it is for or named a practice. Ask once when they did not;
  omit it when they want to just start.
- `voice_id` (string, optional): a `voice_id` from `list_voices`. Meditations use
  SUN's calm meditation voices and keep a chosen voice only for some of the
  user's own cloned voices.
- `course_language` (`en` | `es` | `hi` | `zh`, optional): only when the user
  explicitly asks for a language; with a voice it must match the voice's
  language.

Result: as for `create_audio_course` (without `files`), plus
`content_type: "meditation"` and, when the chosen voice was replaced,
`voice_note` (a sentence to pass on to the user).

Errors: `voice_not_available`, `voice_language_mismatch`,
`voice_catalog_unavailable`, as for `create_audio_course`.

## `create_story`

Starts one asynchronous piece of fiction told in chapters by one narrator: a
bedtime story, fairy tale, fable, adventure, or a made-up story about people the
user names. Non-fiction told as a story ("the story of Rome"), biographies and
analysing a novel use `create_audio_course`.

Inputs:

- `request` (string, required): 1 to 4,000 characters; the user's own words,
  keeping every name and detail.
- `duration_minutes` (integer, optional): 5 to 30; defaults to 10.
- `voice_id` (string, optional): a `voice_id` from `list_voices`, including the
  user's cloned voices (`kind: "cloned"`).
- `course_language` (`en` | `es` | `hi` | `zh`, optional): as for
  `create_meditation`.

A story is never told by characters; there is no `character_ids` input. When
the user asks for their own voice and has no cloned voice, tell them they can
clone it in the SUN app (https://sunapp.ai) and offer one of SUN's voices.

Result: as for `create_audio_course` (without `files`), plus
`content_type: "story"`.

Errors: `voice_not_available`, `voice_language_mismatch`,
`voice_catalog_unavailable`, as for `create_audio_course`.

## `create_song`

Starts composing one original song sung by SUN's music engine: a song, jingle,
rap, lullaby, birthday song, lofi beats. Learning about music (its history or
theory, how to write a song) uses `create_audio_course`. Listed only while songs
are enabled on the server.

Inputs:

- `song_request` (string, required): 1 to 4,000 characters; the user's request
  in their own words and language, keeping every name, detail, mood and genre.
- `length_seconds` (integer, optional): 10 to 300, only when the user named a
  length; defaults to 180.

A song has no narrator voice, characters or course language; its lyrics follow
the request's language. It cannot imitate a real artist, band, song, album or
composer, or use existing lyrics: describe that sound instead (genre, era,
instruments, tempo, mood, vocal delivery) and tell the user. An artist who is
the song's subject stays as written.

Result: as for `create_audio_course` (without `files`), plus
`content_type: "song"`.

Errors refused before anything is created (no credits used):

| `code`                 | Meaning                                                                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `song_imitates_artist` | `song_request` asks to imitate a named artist, band, song or album. Reword the imitation as a description of the sound and call again. |

If the music engine itself refuses a request, it composes from its own reworded
version instead, so the user still gets a song.

## `create_source_file_upload`

Gets a one-time link for uploading a file that exists only as a path on the
user's computer. Only for clients that can read local files and run shell
commands, such as Codex; never needed in ChatGPT, where attachments go in
`create_audio_course`'s `files`. Needs the `courses:write` scope.

Inputs:

- `file_name` (string, required): 1 to 255 characters, e.g. `notes.pdf`.
- `size_bytes` (integer, optional): the file's size, when known. Files over
  512 MB are refused before a link is made.
- `mime_type` (string, optional): up to 255 characters, e.g. `application/pdf`.

At most 20 links can be open per connection at once (`too_many_upload_links`);
unused links expire after 10 minutes.

Result:

```json
{
  "upload_url": "https://api.sunapp.ai/mcp/uploads",
  "upload_token": "string",
  "method": "POST",
  "form_field": "file",
  "expires_at": "2026-10-01T12:10:00+00:00",
  "expires_in_seconds": 600,
  "max_bytes": 536870912
}
```

Upload with the skill's script, which sends the token as a bearer header
(passed to curl on stdin, never on its command line), only to SUN's upload URL,
and quotes paths with spaces or brackets:

```bash
SUN_UPLOAD_TOKEN="<upload_token>" scripts/upload_source_file.sh "/path/to/file.pdf" "<upload_url>"
```

which is equivalent to:

```bash
curl -sS --fail-with-body -X POST -H "Authorization: Bearer <upload_token>" \
  -F 'file=@"/path/to/file.pdf"' "<upload_url>"
```

Upload response (HTTP 200):

```json
{
  "file_id": "string",
  "file_name": "file.pdf",
  "status": "stored",
  "size_bytes": 123456,
  "deduplicated": false
}
```

Pass `file_id` in `create_audio_course`'s `file_ids`. `deduplicated: true`
means the account already had these exact bytes and the existing file is reused.

Upload errors (`{"error": {"code", "message"}}`):

| HTTP | `code`                  | Meaning                                                                    |
| ---- | ----------------------- | -------------------------------------------------------------------------- |
| 404  | `upload_link_invalid`   | The token is expired, already used, or unknown. Request a new link.        |
| 403  | `connection_revoked`    | The SUN connection that made the link was disconnected. Reconnect SUN.     |
| 400  | `missing_file`          | The body had no multipart `file` part.                                     |
| 411  | `length_required`       | The request had no `Content-Length`.                                       |
| 413  | `file_too_large`        | Over 512 MB (checked on the bytes received, not only the declared length). |
| 400  | `chunked_not_supported` | Chunked transfer encoding; send a Content-Length.                          |
| 400  | `invalid_multipart`     | The body is not valid multipart.                                           |
| 502  | `upload_failed`         | SUN could not store the file; request a new link and retry.                |
| 4xx  | genesis codes           | The file type or contents were refused; relay the message.                 |

Each link works once, including when the upload fails: request a new link
rather than retrying with the same token.

## `get_course_status`

Reads generation progress.

Input:

- `job_id` (string, required): the generation job ID returned by
  `create_audio_course`.

Result:

```json
{
  "job_id": "string",
  "course_id": "string | null",
  "status": "PENDING | PROCESSING | SUCCESS | ERROR",
  "created_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp | null",
  "progress": 42,
  "listen_url": "https://sunapp.ai/item/<course_id> | null",
  "error": {
    "message": "string",
    "retryable": false
  }
}
```

`progress` and `error` may be null until they are available. `listen_url` is
null until the course exists.

## `get_course`

Reads the finished result of any generation: a course, meditation, story or
song.

Inputs:

- `job_id` (string, required): the generation job ID.
- `include_partial` (boolean, optional): defaults to `false`; set to `true` to
  return lectures that finished before the whole course.

Result:

```json
{
  "job_id": "string",
  "course_id": "string",
  "name": "Course title",
  "description": "Course description | null",
  "duration_ms": 840000,
  "image_url": "https://example.com/course-cover.png",
  "audio_format": "mp3",
  "content_type": "course | meditation | story | song",
  "genesis_mode": "string",
  "session_kind": "meditation | null",
  "lyrics": "string | null",
  "listen_url": "https://sunapp.ai/item/<course_id>",
  "lectures": [
    {
      "id": "string",
      "number": 1,
      "title": "Lecture title",
      "duration_ms": 280000,
      "audio_url": "https://example.com/lecture.mp3",
      "image_url": "https://example.com/lecture.png"
    }
  ],
  "generation": {
    "cost_usd": 0.42,
    "completed_at": "ISO-8601 timestamp | null"
  },
  "intro": {
    "status": "generating | ready | skipped | failed",
    "audio_url": "https://example.com/intro.mp3",
    "duration_ms": 45000,
    "text": "string | null"
  },
  "sources": [
    {
      "file_id": "string",
      "file_name": "notes.pdf",
      "status": "parsed",
      "source_type": "pdf",
      "grounds_text": true
    }
  ]
}
```

`description`, `duration_ms`, `image_url`, lecture `duration_ms`, lecture
`image_url`, and lecture `audio_url` may be null. `intro` is present only for
courses built from files, and `sources` lists those files. With
`include_partial` set to `false`, a course that is not ready returns a
`not_ready` error. Lecture audio links are signed and expire after seven days;
do not cache them. `image_url` is the course-level cover; do not substitute a
lecture image for it.

`content_type` says what was made. A meditation plays as one session although
it arrives in several lectures; a story's lectures are its chapters; a song is
one lecture, and `lyrics` holds its words one line per row (null for an
instrumental, or while they are still being written). `listen_url` plays
whatever is ready and does not expire.

## `get_source_file_status`

Reports how SUN is processing an attached file.

Input:

- `file_id` (string, required): a `file_id` from `create_audio_course`'s
  `files`.

The result carries the file's `status` (`receiving`, `stored`, `parsing`,
`parsed`, or `error`), its `file_name`, and, once parsed, `page_count` and
`word_count`. An `error` status includes `error.message`, the reason to give the
user before they re-upload.

## `whoami`

Confirms the connected account without using any credits. It takes no
inputs.

Result:

```json
{
  "user_id": "string",
  "token_id": "string"
}
```

Treat these identifiers as connectivity evidence. Do not repeat `token_id` in
ordinary user-facing responses.

## `get_credit_balance`

Tells the user how much they can still generate. It takes no inputs, uses no
credits, and does not count toward the create tools' request limit.

Result:

```json
{
  "spendable_credits": 5400,
  "available_minutes": 90,
  "has_active_subscription": true
}
```

`available_minutes` is how many minutes of audio the balance covers (60 credits
per minute). Answer with the tool's own sentence ("You have about 90 minutes of
SUN credits available (5,400 credits)."). `has_active_subscription` is only a
yes or no: do not describe plans, prices or renewals. If the user asks how to
get more credits, share https://sunapp.ai/faq#billing.

Errors: the usual authentication failures, and `billing_unavailable` when the
balance cannot be read right now (no `_meta`; suggest trying again shortly).

## `list_voices`

Lists the voices a course or briefing can be narrated in: SUN's own voices and
the user's own cloned voices (never other users' voices).

Input:

- `language` (`en` | `es` | `hi` | `zh`, optional): only voices that speak that
  course language.

Result:

```json
{
  "voices": [
    {
      "voice_id": "string",
      "display_name": "string",
      "kind": "preset | cloned",
      "language": "en | es | hi | zh | null",
      "language_code": "en-GB",
      "gender": "male | female | nonbinary | null",
      "trait": "string | null",
      "preview_url": "https://example.com/preview.mp3 | null"
    }
  ]
}
```

Cloned voices have no `preview_url`, `gender`, or `trait`. A `voice_id` passed
to `create_audio_course` or `schedule_briefing` must come from this list. A
failed lookup is a `voice_catalog_unavailable` error, never a shorter list.

## `list_characters`

Lists the SUN characters that can teach a course. It takes no inputs.

Result:

```json
{
  "characters": [
    {
      "id": "string",
      "display_name": "string",
      "character_name": "string",
      "tone": "string",
      "gender": "string",
      "nationality": "string",
      "primary_language": "string",
      "ai_recreation_disclosure": "string | null"
    }
  ]
}
```

`primary_language` is part of the persona and does not set the course
language. Some two-character pairs are unavailable for courses built from
files or for briefings; SUN says so when it refuses.

## `schedule_briefing`

Sets up a recurring or one-off briefing. Nothing is generated when it is
created: at each scheduled time SUN researches the topic and sends a push to
the SUN app, and the briefing plays when the user taps it. The call is not
idempotent: calling it twice creates two briefings.

Inputs:

- `title` (string, required): 1 to 200 characters, shown on the notification.
- `instructions` (string, required): 1 to 4,000 characters; the standing brief.
- `schedule` (object, required): `kind` (`once` | `daily` | `weekdays` |
  `weekly`) and `time` (`HH:MM`, 24-hour local time); `weekdays` (ISO 1 to 7)
  with `weekly`; `date` (`YYYY-MM-DD`) with `once`.
- `time_zone` (string, required): an IANA region name such as `Asia/Shanghai`,
  or `UTC`. Abbreviations and offsets (`EST`, `GMT+8`) are refused.
- `voice_id`, `character_ids`, `course_language`: as for `create_audio_course`.
- `duration_minutes` (integer, optional): 5 to 120.

Result: the briefing summary (`task_id`, `title`, `instructions`, `schedule`,
`schedule_description`, `time_zone`, `status`, `next_run_at`, `last_run_at`,
`created_at`, `origin: "chatgpt_plugin"`) plus `app_required` (boolean) and,
when true, `app_download_url`. `app_required` means the user has no SUN app that
has been active in the last 30 days, so the pushes would not reach them.

Errors (nothing is created): `invalid_time_zone`, `invalid_briefing` (the
schedule is invalid, a one-off time is in the past, or the two characters
cannot share a briefing; the message says which), plus the voice and character
codes listed for `create_audio_course`.

## `list_scheduled_briefings`

Lists the user's briefings, including ones set up in the SUN app.

Input:

- `include_inactive` (boolean, optional): defaults to `false` (active and
  paused only); `true` also returns finished and cancelled briefings.

Result: `{"scheduled_tasks": [<briefing summary>, ...]}`. Each summary has the
fields listed under `schedule_briefing`, and its `origin` is `app` or
`chatgpt_plugin`.

Briefings cannot be edited. To change the time or topic, cancel the briefing
and schedule a new one, and only after the user agrees.

## `cancel_scheduled_briefing`

Cancels a briefing for good.

Inputs:

- `task_id` (string, required): a `task_id` from `list_scheduled_briefings`.
- `reason` (string, optional): a short note for diagnostics.

Result: the briefing summary with `status: "cancelled"` and
`already_cancelled` (`true` when it had been cancelled before; cancelling twice
is not an error). An unknown, malformed, or other user's `task_id` returns
`briefing_not_found`.
