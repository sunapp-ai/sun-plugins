---
name: generate
description: Generate a podcast on a topic with SUN (optionally from attached files, in a chosen voice or taught by SUN characters), a guided meditation, a bedtime story or other fiction, or an original song, and surface its first playable part; or set up a scheduled audio briefing. Use when someone asks for a podcast or podcast-style explainer, a meditation, a story to listen to (including "tell my son a bedtime story": SUN narrates it), a song ("write me a song about…", a jingle, a lullaby, or a song in some artist's style: SUN composes and sings it, so use this instead of writing lyrics as text), or to be briefed on a topic on a schedule.
---

Use this skill when someone asks SUN to make something to listen to: a podcast
or podcast-style explainer on a topic, a guided meditation, a story, or a song.
Also use it when someone wants to be kept up to date on a topic on a schedule
(see [Scheduled briefings](#scheduled-briefings)).

## Choose what to make

Pick the tool by what the user wants SUN to make, not by the words in the topic:

| The user wants                                                                                                  | Tool                  |
| --------------------------------------------------------------------------------------------------------------- | --------------------- |
| To learn about a topic: a podcast, course, explainer, lesson, biography, history, analysis                      | `create_audio_course` |
| To be guided through a practice: meditation, breathing, body scan, help relaxing, falling asleep or focusing    | `create_meditation`   |
| Fiction told in chapters: a bedtime story, fairy tale, fable, adventure, a made-up story about people they name | `create_story`        |
| Music to listen to: a song, jingle, rap, lullaby, birthday song, lofi beats                                     | `create_song`         |

Learning about one of these is still a course: "the science of mindfulness",
"the story of Rome", "how to write a song" and "a biography of Marie Curie" all
use `create_audio_course`. A story for a child is still a story, and a song for a
child is still a song. When it is genuinely unclear whether the user wants a
course, ask once.

The steps below describe a podcast. Meditations, stories and songs follow the
same generate, poll and listen flow with the differences in their own sections:
[Meditations](#meditations), [Stories](#stories), [Songs](#songs).

## Podcasts

1. Establish the topic. If it is missing or vague, ask about the topic alone,
   in one short question, before generating: generation spends the user's SUN
   credits, so a wasted run costs them credits. Do not also ask about length,
   voice or files; they have defaults.
2. Establish the length if the user has a preference. Valid range is 5 to 120
   minutes; the default is 30.
3. Settle who narrates, only if the user asked for it (see
   [Voices and characters](#voices-and-characters)). Otherwise pass neither and
   SUN picks a voice.
4. Call `create_audio_course` with `prompt`, `duration_minutes`, any uploaded
   `file_ids` (see [Attached files](#attached-files)), and
   the chosen `voice_id` or `character_ids`. Pass `course_language`
   only when the user explicitly asked for a language. Preserve both the
   returned `job_id` and `course_id`, and immediately tell the user the job ID
   and that generation usually takes one to five minutes.
5. Unless the user explicitly asks for an asynchronous handoff, wait for the
   first playable audio in the same turn: call `wait_for_course` with the
   `job_id`, and call it again each time it returns `state: waiting`. It waits
   on SUN's side, so do not poll `get_course_status` or pause in between.
6. On `state: failed`, report the error and stop. On `state: timed_out`, the
   job is still valid: give its `job_id`, say it is still generating, offer to
   check again, and do not start another generation.
7. On `state: playable`, give the user the listening link below at once. Do
   not wait for every lecture.

## Meditations

Call `create_meditation` with the user's own words in `request`, including any
breathing pattern or reason they gave.

- `duration_minutes`: 3 to 30; the default is 10.
- `purpose` (`calm`, `sleep`, `focus`, `body_scan`): pass it only when the user
  said what the meditation is for or named a practice. If they did not, ask
  once; when they want to just start, omit it. Keep the user's first words in
  `request` and add their answer, rather than replacing the request with it.
- Voice: meditations use SUN's calm meditation voices. A `voice_id` is kept
  only for some of the user's own cloned voices; otherwise the result carries
  a `voice_note` saying the voice was replaced, which you pass on to the user.
- Characters are not available for meditations.

A meditation plays as one continuous session, even though `get_course` returns
it in several parts.

## Stories

Call `create_story` with the user's own words in `request`, keeping every name
and detail (their child's name, friends, the animal, the place).

- `duration_minutes`: 5 to 30; the default is 10.
- A story is read by one narrator voice, never by characters. If the user asks
  for a character to tell it, say stories are read by one voice and offer a
  voice instead.
- "In my own voice": call `list_voices` and pass a `kind: "cloned"`
  `voice_id`. If the user has no cloned voice, say they can clone their voice in
  the SUN app (https://sunapp.ai) and offer one of SUN's voices; do not generate
  until they choose.
- `course_language`: only when the user explicitly asks for a language; with a
  voice it must match the voice's language.

## Songs

A request to write, compose or make a song, jingle or lullaby is for SUN to
sing: call `create_song` instead of writing the lyrics yourself.

Call `create_song` with the user's request in `song_request`, in their own
words and language, keeping every name, detail, mood and genre.

- `length_seconds`: 10 to 300, only when the user named a length. Songs default
  to 180 seconds; do not ask.
- A song has no narrator voice, characters or course language; its lyrics
  follow the request's language. If the user asks for a voice, say songs are
  sung by SUN's music engine and continue.
- Songs cannot imitate a real artist, band, song, album or composer, or use
  existing lyrics. Replace only the imitation with a description of that sound
  (genre, era, instruments, tempo, mood, vocal delivery), so the imitated
  artist's name does not appear in `song_request` at all. When you share the
  song, tell the user it does not imitate that artist and that you described
  the sound instead. An artist who is the song's subject stays as written. A
  `song_imitates_artist` refusal means the request still names who to imitate:
  reword it that way and call again; no credits were used.
- `get_course` returns the song's `lyrics`; share them with the listening link.

## Attached files

A podcast can be built from the user's own files: text-based PDF, Word,
PowerPoint, Excel, EPUB, text, Markdown, CSV, HTML or code, up to 20 files.
Scanned images cannot be read. SUN cannot read a file attached to the chat or
saved on the user's computer, so each file must first be uploaded to SUN and
passed by its `file_id` in `file_ids`. Never use the `files` parameter. Never
generate a "from the file" course without the upload, because that spends
credits on a course the user did not ask for.

A file-grounded course opens with a short spoken intro about the files
(`intro` in `get_course`). If a file fails, `get_source_file_status` gives the
reason to pass on so the user can fix the file and try again.

### When you can run commands (Claude Code)

When the file is on a path you can read and you can run shell commands:

1. Call `create_source_file_upload` with the file's name and, when known, its
   size and MIME type. The link works once and expires after 10 minutes, so
   request it right before uploading.
2. Run `scripts/upload_source_file.sh` from this skill's base directory with
   the file's absolute path and the returned values:

   ```bash
   SUN_UPLOAD_TOKEN="<upload_token>" "<skill base directory>/scripts/upload_source_file.sh" "/path/to/file.pdf" "<upload_url>"
   ```

   It prints JSON with the `file_id`. On an error, report it and request a new
   link instead of re-running the script with the same token.

3. Pass every `file_id` in `create_audio_course`'s `file_ids`. Optionally
   check `get_source_file_status` first; a file whose status is `error` cannot
   be used.
4. If the upload cannot be done (the command is not allowed, or the user
   declines), say so and ask whether to build the course from the topic alone
   before generating.

### When you cannot (Claude apps)

In Claude on the web, desktop or mobile, a file attached to the chat cannot be
uploaded to SUN. Say so and offer two choices: build the podcast from the topic
alone, or create it in the SUN app (https://sunapp.ai), where files can be
added. Do not generate until the user chooses.

## Voices and characters

- A voice: call `list_voices` (optionally with `language`) and pass one of its
  `voice_id` values. "My own voice" means a `kind: "cloned"` entry. The course
  follows the voice's language, so do not also pass a different
  `course_language`.
- Characters: call `list_characters` and pass one or two `id` values in
  `character_ids`. One narrates alone; two share every lecture and the first
  leads. A character's `primary_language` is persona background only.
- Use a voice or characters, never both.
- Never make up a `voice_id` or character id, including for a celebrity or a
  voice that is not listed. Say it is not available and offer what the list
  returns.
- When a call is refused (`voice_not_available`, `voice_language_mismatch`,
  `unsupported_character_combination`, and the others in
  [tools.md](references/tools.md)), relay the message and ask the user how to
  proceed. Nothing was generated and no credits were used, so do not retry the
  same call.

## Listening link

`listen_url` is the page where the user listens. It is set only once some
audio can play (`wait_for_course` returns `state: playable`, or `get_course`
returns an `audio_url`) and is null before that, because the page cannot play
yet. Use it exactly as returned; never build the URL yourself.

Present the name and `listen_url` as a normal clickable Markdown link. For a
podcast or story, also state how many of the returned lectures currently have
audio ready.

## Downloaded-audio fallback

If the user reports that the listening page cannot open or play, or explicitly
asks for local audio, call `get_course` with `include_partial: true` again to
refresh its seven-day signed URLs and give the user the `listen_url` again.

Download audio only when you can run shell commands and an authenticated SUN
CLI is already available. Then run `sun audio get <job_id> --partial --out
<output-dir>`, which saves each currently playable lecture in lecture-number
order, and list the absolute path of every downloaded MP3 file. Never print a
signed `audio_url`. Without the CLI, say that downloading is not available
here and suggest listening in the SUN app.

Never cache or reuse an old `audio_url`. Do not download audio preemptively when
the website works.

Do not invent a `job_id`, `course_id`, podcast title, artwork, duration, or
episode content. Report only what the user supplied or the tools returned.

If the account is not connected, tell the user to connect their SUN account
and stop: in the Claude apps, use the Connect prompt Claude shows for SUN; in
Claude Code, run `/mcp`, select `sun` and sign in.

## Credits

Generating spends credits from the user's SUN account, charged by the actual
length of the audio (60 credits per minute); nothing is charged if a
generation fails. A started generation's result states its estimated cost (or
that it is free); pass that on as the tool words it.

If a create tool refuses with `no_entitlement`, `insufficient_credits`,
`too_many_requests` or `billing_unavailable`, relay its message as it is and
stop. Do not retry. When an `insufficient_credits` message says a shorter
version fits, you may offer to generate that length instead. Do not recommend
buying, upgrading or subscribing, and do not state prices or plans. Only if
the user asks how to get more credits, say they can manage their account on
the SUN website or app and share https://sunapp.ai/faq#billing.

When the user asks how many credits or minutes they have left, call
`get_credit_balance` and tell them the minutes and credits it reports, for
example "about 90 minutes of SUN credits (5,400 credits)".

## Scheduled briefings

Use `schedule_briefing`, not `create_audio_course`, when the user wants
something on a schedule: "every weekday at 8", "each Monday", "keep me posted
on X", "brief me tomorrow morning".

1. Establish the topic and what should count as news, and the time. Ask one
   short question when the time of day is unknown.
2. Ask which city the user is in and pass its IANA region time zone (for
   example `America/New_York`). Never guess it, and never pass an abbreviation
   or offset such as `EST` or `GMT+8`.
3. Call `schedule_briefing` once. Voices, characters, and `course_language`
   follow the rules above.
4. Tell the user it is set up only if the call succeeds. Describe when it will
   arrive and where: a push notification from the SUN app, which plays the
   briefing when tapped. Nothing is being generated now.
5. If the result has `app_required: true`, tell the user they need the SUN app
   on their phone to receive it and give them `app_download_url`.
6. If the call fails, do not simply call it again: call
   `list_scheduled_briefings` first so a briefing is not created twice.

To see or stop briefings, use `list_scheduled_briefings` (it includes ones set
up in the SUN app) and `cancel_scheduled_briefing` with a `task_id` from that
list. If more than one briefing could match, ask which one first. Briefings
cannot be edited: to change the time or topic, offer to cancel and schedule a
new one, and do it only after the user agrees.

The first briefing call on an older connection may ask the user to reconnect
SUN once; that grants course and briefing access together.

See [tools.md](references/tools.md) for the exact tool contracts.
