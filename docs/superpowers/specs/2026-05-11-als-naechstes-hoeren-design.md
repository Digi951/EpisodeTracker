# "Als naechstes hoeren" — Smart Lists Design

## Goal

Add a fourth tab to HoerspielLog that answers the question: "What should I listen to next?" through six curated Smart Lists. This is the main V1.1 feature.

## Architecture

### Navigation

- New fourth tab **"Als naechstes"** in the existing `TabView` (between Statistiken and Einstellungen)
- Tab icon: `play.circle` (SF Symbol)
- Two-level navigation: Smart List overview → Smart List detail

### Tab Structure

**Level 1 — Smart List Overview (`UpNextView`)**

A `List` showing all six Smart Lists as rows. Each row displays:
- Emoji icon (leading)
- Smart List name
- Teaser subtitle: the title and catalog of the first relevant episode, or "Keine Vorschlaege" in secondary color if empty
- Chevron (trailing, standard `NavigationLink` disclosure)

Tapping a row navigates to the detail view for that Smart List.

**Level 2 — Smart List Detail (`SmartListDetailView`)**

A standard `List` of episodes using the existing `EpisodeRowView`. Tapping an episode navigates to the existing `EpisodeDetailView`. The navigation title shows the Smart List name.

For the two "Zufaellig" lists: a "Neu wuerfeln" button in the toolbar that reshuffles the selection.

**Level 1.5 — Mood Picker (`MoodPickerView`)** (only for "Zufaellig nach Stimmung")

Shown between the overview and the detail view. A `List` of all Moods with:
- Mood emoji icon (leading)
- Mood name
- Count of matching unlistened episodes (trailing, secondary color)
- Chevron (trailing)

Tapping a mood navigates to `SmartListDetailView` filtered by that mood.

### iPad

Same fourth tab. Uses `NavigationSplitView` consistent with the existing Episodes tab (sidebar list + detail). The overview appears in the sidebar column; detail views appear in the detail column.

## Smart List Definitions

All Smart Lists operate on the existing `Episode`, `Universe`, and `Mood` SwiftData models. No schema changes are required.

### 1. Fortsetzen (Continue)

- **Icon:** `▶️`
- **Purpose:** Show the next unlistened episode per catalog, based on where the user left off
- **Query logic:**
  - For each `Universe` that has at least one listened episode:
    - Find the highest `episodeNumber` where `isListened == true` (`maxListened`)
    - Return the episode with the lowest `episodeNumber` where `episodeNumber > maxListened` AND `isListened == false`
  - Sort results by the catalog's most recent `lastListenedAt` (descending) — most recently active catalog first
- **Teaser:** First result (most recently active catalog)
- **Empty state:** "Du bist ueberall auf dem neuesten Stand"

### 2. Lange nicht gehoert (Long time no listen)

- **Icon:** `⏸️`
- **Purpose:** Surface catalogs where the user paused listening a while ago but still has unlistened episodes
- **Query logic:**
  - For each `Universe`:
    - Find the most recent `lastListenedAt` among its episodes
    - If that date is more than 30 days ago AND unlistened episodes exist in that catalog:
      - Return the next continuation episode (same logic as "Fortsetzen")
  - Sort by `lastListenedAt` ascending — longest pause first
- **Teaser:** The catalog with the longest pause
- **Empty state:** "Keine lang pausierten Serien"
- **Note:** The 30-day threshold is a hardcoded constant, not user-configurable in V1.1

### 3. Uebersprungen (Skipped)

- **Icon:** `⏭️`
- **Purpose:** Find episodes the user skipped — unlistened episodes with a lower number than episodes already listened in the same catalog
- **Query logic:**
  - For each `Universe`:
    - Find the highest `episodeNumber` where `isListened == true` (`maxListened`)
    - Fetch all episodes where `episodeNumber < maxListened` AND `isListened == false`
  - Flatten results across all catalogs
  - Sort by `Universe.name` ascending, then `episodeNumber` ascending
- **Teaser:** First skipped episode (alphabetically by catalog)
- **Empty state:** "Keine uebersprungenen Folgen"

### 4. Top bewertet (Top rated)

- **Icon:** `⭐`
- **Purpose:** Highlight unlistened episodes that have been rated (e.g., pre-rated based on reputation, or rated from a previous partial listen)
- **Query logic:**
  - Fetch episodes where `isListened == false` AND `rating != nil`
  - Sort by `rating` descending, then `episodeNumber` ascending
- **Teaser:** Highest-rated unlistened episode (with star display)
- **Empty state:** "Keine bewerteten ungehoerten Folgen"

### 5. Zufaellig (Random)

- **Icon:** `🎲`
- **Purpose:** Suggest random unlistened episodes across all catalogs for spontaneous listening
- **Query logic:**
  - Fetch all episodes where `isListened == false`
  - Shuffle and take up to 10 results
  - Reshuffle on "Neu wuerfeln" button tap
- **Teaser:** First episode from current shuffle
- **Empty state:** "Alles gehoert!"
- **"Neu wuerfeln" button:** Toolbar button that regenerates the random selection

### 6. Zufaellig nach Stimmung (Random by mood)

- **Icon:** `😱`
- **Purpose:** Suggest random unlistened episodes filtered by a specific mood
- **Navigation:** Overview → MoodPickerView → SmartListDetailView
- **Mood picker query:**
  - Fetch all `Mood` objects
  - For each mood: count episodes where `isListened == false` AND mood is assigned
  - Show only moods with count > 0
  - Sort by mood name
- **Detail query (after mood selection):**
  - Fetch episodes where `isListened == false` AND `moods` contains selected mood
  - Shuffle and take up to 10 results
  - Reshuffle on "Neu wuerfeln" button tap
- **Teaser in overview:** "Stimmung waehlen..."
- **Empty state (mood picker):** "Keine Stimmungen mit offenen Folgen"
- **Empty state (detail):** "Keine offenen Folgen mit dieser Stimmung"

## File Structure

New files to create:

| File | Responsibility |
|------|---------------|
| `UpNextView.swift` | Smart List overview (Level 1) — the tab's root view |
| `SmartListDetailView.swift` | Episode list for a selected Smart List (Level 2) |
| `MoodPickerView.swift` | Mood selection for "Zufaellig nach Stimmung" (Level 1.5) |
| `SmartListDefinition.swift` | Enum defining all six Smart Lists with their icons, names, and query logic |

Files to modify:

| File | Change |
|------|--------|
| `ContentView.swift` | Add fourth tab with `UpNextView` |
| `NavigationDestination.swift` | Add cases for Smart List navigation if needed |

No changes to model files (`Episode.swift`, `Mood.swift`, `Universe.swift`).

## Testing

Unit tests for Smart List query logic in `SmartListDefinition`:
- "Fortsetzen" returns correct next episode per catalog
- "Fortsetzen" sorts by most recent catalog activity
- "Uebersprungen" identifies gaps correctly
- "Lange nicht gehoert" respects the 30-day threshold
- "Top bewertet" only includes unlistened episodes with ratings
- "Zufaellig" returns different results on reshuffle
- Empty states: each list returns empty when no episodes match criteria

## Out of Scope

- User-configurable thresholds (e.g., "Lange nicht gehoert" days)
- Freemium/Pro gating of Smart Lists
- Notifications or reminders
- Persistence of random selections across app launches
