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
A Develop adjustment recorded in a photo's history, not counting the import step. Rating, flag, keyword and caption changes are not Edits.
_Avoid_: Change, modification, last edit time

**Edit Window**:
The period of time a Job looks for Edits in. A photo qualifies when any of its Edits falls inside it.
_Avoid_: Date range, time range

**Fixed Edit Window**:
An Edit Window between a start date and an end date, with the end date included.

**Relative Edit Window**:
An Edit Window covering the last N hours or days, measured back from the moment of the Run.

**Run**:
One execution of a Job, which brings its Target Collection up to date as a single undoable change.
_Avoid_: Sync, refresh, execute
