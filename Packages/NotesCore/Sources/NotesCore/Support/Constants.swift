import Foundation

/// アプリ全体で共有する定数。マジックナンバーの直書きを避けるために集約する。
public enum NotesConstants {

    /// 自動保存（F-EDIT-07）に関する設定。
    public enum Autosave {
        /// 入力停止からこの時間が経過したら保存する。
        public static let debounce: Duration = .seconds(1.5)
    }

    /// ゴミ箱（F-ORG-05）に関する設定。
    public enum Trash {
        /// ゴミ箱に保持する日数。経過後は自動削除の対象となる。
        public static let retentionDays: Int = 30
    }

    /// 見出しブロックで許容するレベルの範囲（H1〜H3）。
    public enum Heading {
        public static let minLevel: Int = 1
        public static let maxLevel: Int = 3
    }

    /// テーブルブロックの初期サイズ。
    public enum Table {
        public static let defaultColumnCount: Int = 2
        public static let defaultRowCount: Int = 2
    }

    /// 既定の名称。
    public enum Naming {
        public static let untitledNote = "無題のノート"
        public static let untitledFolder = "新規フォルダ"
        public static let personalWorkspace = "個人ワークスペース"
        public static let localUserDisplayName = "ローカルユーザー"
    }
}
