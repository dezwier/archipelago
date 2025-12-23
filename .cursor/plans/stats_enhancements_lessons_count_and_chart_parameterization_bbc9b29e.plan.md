---
name: "Stats enhancements: lessons count and chart parameterization"
overview: Add lesson count to summary stats endpoint and parameterize the over-time chart endpoint to support exercises, lessons, or lemmas practiced, with a frontend toggle to switch between views.
todos:
  - id: backend-summary-lessons
    content: Add lesson_count to summary stats endpoint - join with Lesson table and count per language
    status: completed
  - id: backend-summary-schema
    content: Update LanguageStat schema to include lesson_count field
    status: completed
  - id: backend-chart-parameterize
    content: Add metric_type parameter to exercises-daily endpoint and implement three query modes (exercises/lessons/lemmas)
    status: completed
  - id: backend-chart-schema
    content: Rename exercises-daily schemas to practice-daily (generic naming)
    status: completed
  - id: frontend-domain-models
    content: "Update domain models: add lessonCount to LanguageStat, rename ExercisesDaily to PracticeDaily"
    status: completed
  - id: frontend-service
    content: "Update StatisticsService: handle lessonCount, rename getExercisesDaily to getPracticeDaily with metricType param"
    status: completed
  - id: frontend-chart-widget
    content: Add toggle UI to chart widget and implement metric type switching logic
    status: completed
    dependencies:
      - frontend-service
  - id: frontend-summary-card
    content: Display lessonCount in language summary card widget
    status: completed
    dependencies:
      - frontend-domain-models
  - id: frontend-profile-screen
    content: Update profile screen to use new practice daily service and pass metric type to chart
    status: completed
    dependencies:
      - frontend-chart-widget
---

# Stats Summary and Over-Time Chart Enhancements

## Overview

1. Add `lesson_count` to the summary stats endpoint (per language, similar to `exercise_count`)
2. Parameterize the `/exercises-daily` endpoint to support showing exercises, lessons, or lemmas practiced over time
3. Add a toggle in the frontend chart widget to switch between the three views

## Implementation Details

### Backend Changes

#### 1. Update Summary Stats Endpoint

**File**: `api/app/api/v1/endpoints/user_lemma_stats.py`

- Modify `get_language_summary_stats()` to include lesson count per language
- Join with `Lesson` table and count distinct lessons per language
- Filter lessons by the same criteria (user_id, learning_language matching lemma language_code)

#### 2. Update Summary Stats Schema

**File**: `api/app/schemas/user_lemma.py`

- Add `lesson_count: int` field to `LanguageStat` model

#### 3. Parameterize Over-Time Endpoint

**File**: `api/app/api/v1/endpoints/user_lemma_stats.py`

- Rename `/exercises-daily` endpoint to `/practice-daily` (or keep name and add parameter)
- Add query parameter `metric_type: str` with values: `"exercises"`, `"lessons"`, or `"lemmas"`
- Refactor query logic to support three modes:
- **exercises**: Current behavior (count exercises per day)
- **lessons**: Count lessons per day (group by lesson end_time date)
- **lemmas**: Count distinct lemmas practiced per day (from exercises, group by exercise end_time date)
- Update response schema to be generic (rename `ExercisesDailyResponse` to `PracticeDailyResponse`)

#### 4. Update Over-Time Schema

**File**: `api/app/schemas/user_lemma.py`

- Rename `ExercisesDailyResponse` to `PracticeDailyResponse`
- Rename `LanguageExerciseData` to `LanguagePracticeData`
- Rename `ExerciseDailyData` to `PracticeDailyData`
- Keep structure the same (date + count)

### Frontend Changes

#### 5. Update Domain Models

**File**: `app/lib/src/features/profile/domain/statistics.dart`

- Add `lessonCount` field to `LanguageStat` class
- Rename `ExercisesDaily` to `PracticeDaily`
- Rename `LanguageExerciseData` to `LanguagePracticeData`
- Rename `ExerciseDailyData` to `PracticeDailyData`
- Update JSON serialization/deserialization

#### 6. Update Statistics Service

**File**: `app/lib/src/features/profile/data/statistics_service.dart`

- Update `getLanguageSummaryStats()` to handle `lessonCount` in response
- Rename `getExercisesDaily()` to `getPracticeDaily()` and add `metricType` parameter
- Update endpoint URL and query parameters

#### 7. Update Chart Widget

**File**: `app/lib/src/features/profile/presentation/widgets/exercises_daily_chart_card.dart`

- Rename widget to `PracticeDailyChartCard` (or keep name)
- Add state management for selected metric type (exercises/lessons/lemmas)
- Add toggle/segmented control UI to switch between metric types
- Update chart title dynamically based on selected metric
- Pass `metricType` parameter when fetching data

#### 8. Update Summary Card Widget

**File**: `app/lib/src/features/profile/presentation/widgets/language_summary_card.dart`

- Display `lessonCount` alongside `lemmaCount` and `exerciseCount`
- Format: "X lessons completed" (similar to existing stats)

#### 9. Update Profile Screen

**File**: `app/lib/src/features/profile/presentation/profile_screen.dart`

- Update variable names from `_exercisesDaily` to `_practiceDaily`
- Update service call to use new method name and pass metric type
- Handle metric type state and pass to chart widget

## Data Flow

```javascript
Frontend Toggle → metricType parameter → Backend endpoint
                                              ↓
                                    Query based on metricType
                                              ↓
                                    Return PracticeDailyResponse
                                              ↓
                                    Frontend updates chart
```



## Notes

- The lesson count in summary should count lessons where `lesson.learning_language` matches the `lemma.language_code`
- For lemmas practiced metric, count distinct `user_lemma_id` from exercises per day