-- USL-224 公式コンテンツviewのGRANTを公式コンテンツ契約に合わせる
--
-- 20260830150000_close_production_only_exposure.sql は、
-- v_word_meanings_with_paths と v_example_contents_with_paths の
-- SELECT を anon にも残した。「基底tableで読めるものしか見えないのだから、
-- viewにも読み取りを残してよい」という判断だった。
--
-- これは 20260812055432_define_official_content_contract.sql の決定と矛盾する。
-- そのmigrationは公式コンテンツを「サインイン後にだけ読める」ものと定め、
-- words / word_meanings / example_contents / decks / deck_words から
-- anon の権限をすべて取り消し、authenticated にだけ SELECT を与えている。
--
-- 実害は出ていない。同じmigrationが view を security_invoker = true にしたため、
-- anon が view を読もうとしても基底tableの権限で弾かれる。
-- ローカルのData API検証で、実際に anon への応答が 401 になることを確認した。
-- つまりデータは漏れていないが、GRANTだけが契約より広い状態で残っている。
--
-- 権限とpolicyは別々に確認するというリポジトリのルール
-- (docs/operations/sql-rules.md) に従い、GRANT側も契約へ揃える。
--
-- 本番への適用はこの課題では行わない。適用はUSL-245で、人間の明示承認を得てから行う。

begin;

revoke all on table public.v_word_meanings_with_paths    from public, anon, authenticated;
revoke all on table public.v_example_contents_with_paths from public, anon, authenticated;

grant select on table public.v_word_meanings_with_paths    to authenticated;
grant select on table public.v_example_contents_with_paths to authenticated;

do $$
declare
  v_view text;
  v_role text;
  v_priv text;
begin
  foreach v_view in array array['v_word_meanings_with_paths', 'v_example_contents_with_paths'] loop
    -- 契約どおり、サインイン後だけ読める
    if not has_table_privilege('authenticated', 'public.' || v_view, 'select') then
      raise exception 'USL-224 verification failed: authenticated lost read access to public.%.', v_view;
    end if;

    foreach v_role in array array['public', 'anon'] loop
      if has_table_privilege(v_role, 'public.' || v_view, 'select') then
        raise exception
          'USL-224 verification failed: role % can still read public.%, which contradicts the official content contract.',
          v_role, v_view;
      end if;
    end loop;

    -- 書込経路は誰にも残さない
    foreach v_role in array array['public', 'anon', 'authenticated'] loop
      foreach v_priv in array array['insert', 'update', 'delete'] loop
        if has_table_privilege(v_role, 'public.' || v_view, v_priv) then
          raise exception 'USL-224 verification failed: role % still has % on public.%.', v_role, v_priv, v_view;
        end if;
      end loop;
    end loop;
  end loop;
end
$$;

commit;
