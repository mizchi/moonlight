// Lazy Loader for Moonlight Editor
// 軽量な Viewer を先にロードし、編集が必要になったらフルエディタをロード

type EditorHandle = {
  exportSvg: () => string;
  importSvg: (svg: string) => void;
  clear: () => void;
  destroy: () => void;
  hasFocus: () => boolean;
  onChange: (callback: () => void) => void;
};

type EditorOptions = {
  width?: number;
  height?: number;
  theme?: 'light' | 'dark';
  readonly?: boolean;
  initialSvg?: string;
};

// エディタモジュールのキャッシュ
let editorModulePromise: Promise<void> | null = null;

/**
 * フルエディタモジュールを動的にロード
 */
async function loadEditorModule(): Promise<void> {
  if (!editorModulePromise) {
    editorModulePromise = import('mbt:mizchi/moonlight/embed').then(() => {});
  }
  return editorModulePromise;
}

/**
 * 軽量な SVG ビューアを作成（編集不可、28KB）
 */
export function createViewer(container: HTMLElement, svg: string): void {
  container.innerHTML = svg;
}

/**
 * フルエディタを作成（遅延ロード、186KB）
 */
export async function createEditor(
  container: HTMLElement,
  options: EditorOptions = {}
): Promise<EditorHandle> {
  await loadEditorModule();
  return (window as any).MoonlightEditor.create(container, options);
}

/**
 * ビューア → エディタへのアップグレード
 * 最初は軽量表示、クリックでフルエディタをロード
 */
export function createUpgradableViewer(
  container: HTMLElement,
  svg: string,
  options: EditorOptions = {}
): {
  upgradeToEditor: () => Promise<EditorHandle>;
} {
  // 最初は SVG を表示
  container.innerHTML = svg;
  container.style.cursor = 'pointer';

  let editor: EditorHandle | null = null;

  const upgradeToEditor = async () => {
    if (editor) return editor;

    container.style.cursor = 'default';
    container.innerHTML = '';

    editor = await createEditor(container, {
      ...options,
      initialSvg: svg,
    });

    return editor;
  };

  // クリックでエディタにアップグレード
  container.addEventListener('click', () => upgradeToEditor(), { once: true });

  return { upgradeToEditor };
}
