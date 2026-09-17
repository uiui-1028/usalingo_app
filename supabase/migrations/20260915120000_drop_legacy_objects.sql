-- 使われなくなった古い表・view・関数・Storage bucketを片付ける。
-- 本番には 2026-09-17 に利用者がSQLエディタで適用済み。この版はその記録。
-- 残すもの: 現行の表、トリガー用関数、content-images / content-audio、
-- Make の keep-alive 用 pause.saver.ipaas。

-- 画像アップロードごとに illustration_asset_path を完全URLで上書きしていた仕掛け
drop function if exists public.handle_storage_upload() cascade;

drop view if exists public.v_word_meanings_with_paths, public.v_example_contents_with_paths,
  public.v_index_usage_stats, public.v_index_monitoring,
  public.v_database_size_monitoring, public.v_table_stats_monitoring;

drop function if exists
  public.apply_migration(character varying, character varying, text, character varying, text),
  public.check_asset_linking_status(), public.check_migration_status(),
  public.find_duplicate_indexes(), public.find_missing_assets(),
  public.generate_audio_example_filename(integer), public.generate_audio_meaning_filename(integer),
  public.generate_image_example_filename(integer),
  public.get_asset_folder_path(integer, integer), public.get_asset_folder_path_500(integer, integer),
  public.get_audio_example_asset_path(integer), public.get_audio_example_path(integer),
  public.get_audio_meaning_asset_path(integer), public.get_audio_meaning_path(integer),
  public.get_example_audio_path(integer, text, text), public.get_example_illustration_path(integer, text, text),
  public.get_image_example_asset_path(integer), public.get_image_example_path(integer),
  public.get_index_recommendations(), public.get_index_usage_stats(),
  public.get_migration_status(character varying), public.get_performance_summary(),
  public.get_rename_operations(), public.get_required_storage_folders(),
  public.get_storage_structure_summary(), public.get_word_audio_path(integer, text),
  public.manual_asset_linking(), public.move_files_to_inbox(),
  public.optimize_content_audio_policies(), public.rollback_migration(character varying),
  public.search_all(text, real, integer), public.search_examples(text, text, real, integer),
  public.search_meanings(text, real, integer), public.search_words(text, real, integer),
  public.setup_content_images_policies(),
  public.trigger_asset_linking_corrected(), public.trigger_queue_asset_verification(),
  public.trigger_set_asset_path_immediate(), public.update_asset_paths_to_existing_buckets(),
  public.validate_collocations_structure(jsonb), public.validate_derivatives_structure(jsonb),
  public.validate_inflections_structure(jsonb), public.validate_related_phrases_structure(jsonb);

-- user_learning_progress は 20260810065120 で user_card_progress へ移し済み。
-- デッキの中身は cards が持つので deck_words は不要。
drop table if exists public.user_learning_progress, public.deck_words, public.user_settings,
  public.user_widget_layouts, public.asset_processing_queue, public.schema_migrations;

drop policy if exists "Authenticated users can upload illustrations" on storage.objects;
drop policy if exists "Public Access" on storage.objects;
drop policy if exists "Users can delete their own illustrations" on storage.objects;
drop policy if exists "Users can update their own illustrations" on storage.objects;
drop policy if exists "asset-inbox-delete-policy" on storage.objects;
drop policy if exists "asset-inbox-select-policy" on storage.objects;
drop policy if exists "asset-inbox-upload-policy" on storage.objects;
drop policy if exists "public-delete-policy" on storage.objects;
drop policy if exists "public-select-policy" on storage.objects;
drop policy if exists "public-upload-policy" on storage.objects;
drop policy if exists user_uploads_delete_policy on storage.objects;
drop policy if exists user_uploads_insert_policy on storage.objects;
drop policy if exists user_uploads_select_policy on storage.objects;
drop policy if exists user_uploads_update_policy on storage.objects;

do $$ begin
  if exists (select 1 from storage.objects
             where bucket_id in ('asset-inbox','illustrations','public','user-uploads')) then
    raise exception 'legacy bucket is not empty';
  end if;
end $$;

select set_config('storage.allow_delete_query', 'true', true);
delete from storage.buckets where id in ('asset-inbox','illustrations','public','user-uploads');
