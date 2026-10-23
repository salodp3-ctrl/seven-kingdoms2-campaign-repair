SEVEN KINGDOMS II HD - CAMPAIGN REPAIR KIT 1.0

KEEP THIS WHOLE FOLDER (OR THE ZIP) OUTSIDE THE STEAM GAME FOLDER.
You can copy it to Documents, a USB drive, or your own backup storage.
No Python, downloads, or additional installation is required to run it.

USE AFTER A REINSTALL, STEAM UPDATE, OR VERIFY INTEGRITY
1. Close Seven Kingdoms II and its error boxes. Let Steam finish any updates.
2. Double-click Run Campaign Repair.cmd.
3. Accept the Windows administrator prompt so the installer can update the game.
4. Choose your Steam or GOG installation, or B to locate its 7K2.exe.
5. Choose 1 to apply. Wait for SUCCESS or Already repaired.
6. Launch normally using Steam Play or your usual installed-game shortcut.
7. Select the profile containing your existing campaign saves.
8. After the campaign transition succeeds, save to a NEW slot.

Choose 2 to check whether the repair is installed.
Choose 3 to restore the backed-up original executable.
If no original backup remains, Steam Verify integrity restores the official file.
Steam may remove the repair when updating/verifying files; rerun this kit afterward.
There is no background monitor or automatic modification of future versions.

WHAT IT FIXES
The campaign's monster selector allocates seven entries but incorrectly searches
through twelve, allowing invalid monster species and out-of-bounds memory access.
This can cause garbled SPRITE filenames and crashes at campaign-map transitions.
The repair limits monster selection to seven while preserving all twelve human races.
Existing invalid negative campaign species are replaced with Minotauros (type 4)
when the kingdom is accessed. That correction persists when the game is saved.
Campaign animations and choice code are not skipped or modified by this repair.

SUPPORTED EXECUTABLES (EXACT SHA256 MATCH REQUIRED)
Steam build 8890160:
b866df4b47e6d82105dd52a4dbfd5106ad51df104d629bdf09b4425b06a51c06
GOG 2.10E HD:
fc9e5a4b0d284b6148b19f867ff42e7e5d6f18840202e98d925cd89fe046cffa

An unknown version is refused without changes. It may contain an official fix or
require an adapted patch. Do not force this kit onto another build or a modified
executable, including the earlier skip-animation test copy.

BACKUPS AND RECOVERY
Original and before-change executables are kept in CampaignRepairBackups inside
the selected game folder. Save files are not edited by the installer. Back up your
save folder separately before reinstalling Windows or deleting game data; this
kit cannot recover deleted saves. Repaired campaign data changes in memory and
is retained when YOU save in game.
If Windows is interrupted during file replacement and 7K2.exe is missing, restore
the verified original from CampaignRepairBackups or use Steam Verify integrity.

VALIDATION
Both supported editions passed 230 emulated machine-code test cases each, at two
load addresses. Tests reproduce the original out-of-bounds read, verify repaired
selection and stack cleanup, retain all human races, and repair invalid species.
The affected campaign successfully passed its previously failing transition using
the GOG-based repair. The Steam adaptation passed machine-code tests and was
installed and hash-verified. Wider community testing is welcome.
Installer checks cover apply, repeated apply, restore, repeated restore,
reapplication after simulated reinstall, unknown versions, and corrupt backups.

LIMITATIONS
Unofficial, targeted repair for this campaign bug, not a universal crash fixer.
Other bugs need separate diagnosis. Keep several campaign saves as you progress.
This kit contains patch data, not a complete game executable.
