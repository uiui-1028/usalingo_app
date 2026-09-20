select json_build_object(
  'deck', (
    select json_build_object('id', d.id, 'deck_name', d.deck_name, 'description', d.description, 'owner_id', d.owner_id)
    from public.decks d where d.is_starter and d.owner_id is null order by d.id limit 1
  ),
  'cards', (
    select coalesce(json_agg(card order by card_sort, card_id), '[]'::json)
    from (
      select c.sort_order as card_sort, c.id as card_id, json_build_object(
        'id', c.id,
        'word_id', c.word_id,
        'sort_order', c.sort_order,
        'primary_meaning_id', c.primary_meaning_id,
        'word', json_build_object(
          'id', w.id,
          'word_text', w.word_text,
          'word_meanings', (
            select coalesce(json_agg(json_build_object(
              'id', m.id,
              'priority', m.priority,
              'part_of_speech_en', m.part_of_speech_en,
              'definition_jp', m.definition_jp,
              'etymology', m.etymology,
              'synonyms', m.synonyms,
              'example_contents', (
                select coalesce(json_agg(json_build_object(
                  'id', e.id,
                  'sentence_en', e.sentence_en,
                  'sentence_jp', e.sentence_jp,
                  'image_asset_path', e.image_asset_path,
                  'audio_asset_path', e.audio_asset_path
                ) order by e.display_order nulls last, e.id), '[]'::json)
                from public.example_contents e where e.meaning_id = m.id
              )
            ) order by m.priority nulls last, m.id), '[]'::json)
            from public.word_meanings m where m.word_id = w.id
          ),
          'word_pronunciations', (
            select coalesce(json_agg(json_build_object(
              'audio_asset_path', p.audio_asset_path,
              'is_primary', p.is_primary
            ) order by p.display_order nulls last, p.id), '[]'::json)
            from public.word_pronunciations p where p.word_id = w.id
          )
        )
      ) as card
      from public.cards c
      join public.words w on w.id = c.word_id
      where c.deck_id = (select d.id from public.decks d where d.is_starter and d.owner_id is null order by d.id limit 1)
        and c.is_active
    ) rows
  )
) as payload;
