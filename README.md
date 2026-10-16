# Stash: Save Notes

I kept losing things I wanted to come back to. A link would sit in a WhatsApp
chat, a screenshot would be buried in my gallery, or a note would end up in
some random app. So I built Stash, one place on my phone where I can throw all
of it and find it again later.

There's no account and no server. Everything stays on your phone, and you can
export it or wipe it whenever you like.

**Track:** First year. Stage 1, Stage 3 (Share into the app) and
Mission E (Data ownership). Stage 2 is for second years, so I skipped it.

## What it does

- Save notes, links and images, and add tags to them
- Open, edit, archive, restore and delete anything you've saved
- Search by title, content, link or tag, and filter by notes, links or images
- Your data is still there after you close and reopen the app
- Light, dark and system themes
- Empty or odd input shows a message instead of crashing the app

## Share into Stash (Stage 3)

Stash appears in Android's normal Share menu. If you're reading an article in
Chrome, tap Share and pick Stash. The editor opens with the link already filled
in, so you can add a title or tags before saving. You can also share selected
text, or one or more photos from your gallery.

It works whether the app was closed or already open. If something unusual comes
in, such as an empty share, very long text, a video, a PDF or a broken image,
Stash tells you it can't save it. It doesn't crash.

## Your data, your call (Mission E)

- **Export:** you get a zip file with a readable `stash_export.json` holding
  every item, plus an `images/` folder with your photos. You can open it on
  any computer.
- **Delete account & all data:** Stash has no online account, so your account
  is just the data on your phone. One button, after a confirmation, removes
  every item, every saved image and your settings.
- The Your Data screen explains in plain words where your data lives and what
  happens when you delete it.


## Architecture

Stage 1 is **Mobile App → Local Storage**. Stage 3 adds sharing into the app, and Mission E adds export and delete.

**Where data is stored:** items go in a SQLite database on the phone, and images are copied into the app's private folder. There's no login and no server, and nothing leaves the phone unless you export it.


## Authentication and privacy

Stash has no login, because there's no server and no shared data.
- **Authentication:** none needed. The app works for one person, on their own phone.
- **Where data is stored:** a SQLite database and the app's private folder on the device.
- **How one user's data is protected from another:** Android's app sandbox
  keeps every app's private storage separate, so other apps and other phone users
  can't read Stash's data. Nothing is uploaded anywhere.



## Decisions I made, and why

- **Local only.** I wanted it to work offline and keep people's stuff
  private. With no server, there's nothing to leak.
- **Shares open the editor instead of saving straight away.** That way you
  can fix the title or add tags first, and you never end up with junk items
  you didn't mean to save.
- **Shared images are copied in right away.** Android often hands over a
  temporary file that can disappear later, so Stash keeps its own copy.
- **Export is a zip.** When I tried sending a JSON file and images together,
  WhatsApp dropped the files. One zip fixes that and keeps everything together.

## How to run it

**Easiest:** download `stash.apk` from the
[Releases](https://github.com/VANSH-AGGARWAL2008/stash/releases) page and install it on
an Android phone. You may need to allow installs from unknown sources.

**From the source:**


**Quick test:** open an article in Chrome, tap Share, then Stash. Then go to
⋯ → Your Data and try Export and Delete.

## Known issues

- **Android only for now.** Sharing into the app on iOS needs a Share
  Extension, which I haven't set up yet.
- **You can't paste an image from the clipboard.** Pasting works for text
  and links. For images, use "Add image" in the editor or share the photo in.
- **The Google app shares most images as links,** so they get saved as
  links. To save the actual image, download it and share it from Gallery or
  Google Photos.
- **No import yet.** You can export a backup, but you can't restore it in
  the app. That's next on my list.
- **No cloud sync.** This one is on purpose.

## Built with

Flutter · sqflite · receive_sharing_intent · share_plus · archive ·
image_picker · shared_preferences · path_provider

## Help I used

Package docs, Flutter docs and an AI assistant helped while I was stuck. I can
walk through how every part of the code works.

Made by VANSH AGGARWAL



