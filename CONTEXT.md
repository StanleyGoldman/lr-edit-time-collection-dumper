# Edit Window Jobs

A Lightroom Classic plugin that keeps collections of recently edited photos. Each saved Job turns "photos from these collections that I edited in this period" into a collection the photographer can browse.

## Language

**Job**:
A saved rule that names its Source Collections, its Target Collection and its Edit Window.
_Avoid_: Task, rule, preset

**Source Collection**:
A regular or smart collection whose photos a Job considers.
_Avoid_: Input, source set

**Target Collection**:
The regular collection a Job owns and fills with exactly the photos that qualify, removing every other photo.
_Avoid_: Output, destination, result collection

**Edit**:
A Develop adjustment recorded in a photo's history. History steps that only record the photo arriving, being copied, snapshotted, exported or published are not Edits, and neither are rating, flag, keyword and caption changes.
_Avoid_: Change, modification, last edit time

**Edit Window**:
The period of time a Job looks for Edits in. A photo qualifies when any of its Edits falls inside it.
_Avoid_: Date range, time range

**Fixed Edit Window**:
An Edit Window between a start date and an end date, with the end date included.

**Relative Edit Window**:
An Edit Window that starts N hours or days before the moment of the Run and has no end, so Edits stamped later than the Run still count.

**Run**:
One execution of a Job, which brings its Target Collection up to date as a single undoable change.
_Avoid_: Sync, refresh, execute
