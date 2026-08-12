alter table public.user_learning_progress
  add column if not exists incorrect_count integer not null default 0;

comment on column public.user_learning_progress.incorrect_count is
  'Number of incorrect answers recorded for weak-word detection.';
