/**
 * JSONBカラムのTypeScript型定義
 * 作成日: 2025-10-03
 * 目的: JSONBカラムの型安全性を確保し、データ構造を明確化
 * 参考: usalingo_02_02｜コアコンテンツ定義.md
 */

// =============================================
// 1. inflections (活用形) の型定義
// =============================================

/**
 * 動詞の活用形
 */
export interface Inflections {
  /** 過去形 (例: "did") */
  past?: string;
  /** 過去分詞 (例: "done") */
  past_participle?: string;
  /** 現在分詞 (例: "doing") */
  present_participle?: string;
  /** 三人称単数現在 (例: "does") */
  third_person?: string;
  /** 複数形 (名詞の場合, 例: "boxes") */
  plural?: string;
  /** 比較級 (形容詞の場合, 例: "bigger") */
  comparative?: string;
  /** 最上級 (形容詞の場合, 例: "biggest") */
  superlative?: string;
}

// =============================================
// 2. derivatives (派生語) の型定義
// =============================================

/**
 * 派生語の個別アイテム
 */
export interface DerivativeItem {
  /** 派生語の文字列 (例: "responsible") */
  word: string;
  /** 品詞（日本語） (例: "形容詞") */
  part_of_speech_jp: string;
  /** 品詞（英語） (例: "adjective") */
  part_of_speech_en: string;
  /** 簡単な意味 (例: "責任のある") */
  definition: string;
}

/**
 * 派生語の配列
 */
export type Derivatives = DerivativeItem[];

// =============================================
// 3. collocations (コロケーション) の型定義
// =============================================

/**
 * コロケーションの個別アイテム
 */
export interface CollocationItem {
  /** コロケーションのフレーズ (例: "take responsibility") */
  phrase: string;
  /** フレーズの日本語訳 (例: "責任を負う") */
  translation: string;
}

/**
 * コロケーションカテゴリ
 */
export interface CollocationCategory {
  /** 日本語のカテゴリ名 (例: "動詞 + 名詞") */
  category_jp: string;
  /** 英語のカテゴリ名 (例: "verb + noun") */
  category_en: string;
  /** カテゴリに属するコロケーションのリスト */
  items: CollocationItem[];
}

/**
 * コロケーションの配列
 */
export type Collocations = CollocationCategory[];


// =============================================
// 4. tts_config (TTS設定) の型定義
// =============================================

/**
 * テキスト読み上げ（TTS）の設定
 */
export interface TTSConfig {
  /** TTS機能の有効/無効 */
  enabled: boolean;
  /** 読み上げ速度 (0.5-2.0) */
  voice_speed: number;
  /** 声の高さ (0.5-2.0) */
  voice_pitch: number;
  /** 自動再生の有無 */
  auto_play: boolean;
  /** 読み上げ言語 */
  language: 'en' | 'ja';
  /** 使用する音声ID */
  voice_id?: string;
}

// =============================================
// 5. widget_settings (ウィジェット設定) の型定義
// =============================================

/**
 * ウィジェットの表示オプション
 */
export interface WidgetDisplayOptions {
  /** タイトル表示の有無 */
  show_title: boolean;
  /** 説明表示の有無 */
  show_description: boolean;
  /** 表示するカード数 */
  card_count: number;
  /** 自動更新の有無 */
  auto_refresh: boolean;
}

/**
 * ウィジェットのインタラクション設定
 */
export interface WidgetInteractionSettings {
  /** クリック時の動作 */
  click_action: string;
  /** ホバーエフェクトの有無 */
  hover_effect: boolean;
}

/**
 * ウィジェット固有の設定
 */
export interface WidgetSettings {
  /** ウィジェットタイプ固有の設定 */
  widget_type: Record<string, any>;
  /** 表示オプション */
  display_options: WidgetDisplayOptions;
  /** インタラクション設定 */
  interaction_settings: WidgetInteractionSettings;
}

// =============================================
// 6. バリデーション関数の型定義
// =============================================

/**
 * JSONBデータのバリデーション関数の型
 */
export type JSONBValidator<T> = (data: T) => boolean;

/**
 * 各JSONBカラムのバリデーション関数
 */
export interface JSONBValidators {
  inflections: JSONBValidator<Inflections>;
  derivatives: JSONBValidator<Derivatives>;
  collocations: JSONBValidator<Collocations>;
  ttsConfig: JSONBValidator<TTSConfig>;
  widgetSettings: JSONBValidator<WidgetSettings>;
}

// =============================================
// 7. ユーティリティ型
// =============================================

/**
 * JSONBカラムの型を取得するユーティリティ型
 */
export type JSONBColumnType<T> = T extends 'inflections' ? Inflections
  : T extends 'derivatives' ? Derivatives
  : T extends 'collocations' ? Collocations
  : T extends 'tts_config' ? TTSConfig
  : T extends 'settings' ? WidgetSettings
  : never;

/**
 * 全てのJSONBカラム名
 */
export type JSONBColumnNames = 
  | 'inflections'
  | 'derivatives' 
  | 'collocations'
  | 'tts_config'
  | 'settings';

// =============================================
// 8. デフォルト値の定義
// =============================================

/**
 * TTS設定のデフォルト値
 */
export const DEFAULT_TTS_CONFIG: TTSConfig = {
  enabled: true,
  voice_speed: 1.0,
  voice_pitch: 1.0,
  auto_play: false,
  language: 'en'
};

/**
 * ウィジェット表示オプションのデフォルト値
 */
export const DEFAULT_WIDGET_DISPLAY_OPTIONS: WidgetDisplayOptions = {
  show_title: true,
  show_description: true,
  card_count: 10,
  auto_refresh: false
};

/**
 * ウィジェットインタラクション設定のデフォルト値
 */
export const DEFAULT_WIDGET_INTERACTION_SETTINGS: WidgetInteractionSettings = {
  click_action: 'show_details',
  hover_effect: true
};

// =============================================
// 9. エクスポート
// =============================================

// 型定義とデフォルト値は個別にエクスポート済み
