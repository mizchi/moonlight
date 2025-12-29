// Embed mode entry point

// Import MoonBit embed module
import 'mbt:mizchi/moonlight/embed';

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('editor');
  const output = document.getElementById('output');

  if (!container || !output) {
    console.error('Required elements not found');
    return;
  }

  // Create editor instance
  const editor = (window as any).MoonlightEditor.create(container, {
    width: 600,
    height: 400,
    theme: 'light',
    gridsnap: true,
    toolbarVisible: true
  });

  output.textContent = 'Editor created successfully!';

  // Export SVG button
  document.getElementById('btn-export')?.addEventListener('click', () => {
    const svg = editor.exportSvg();
    output.textContent = svg;
  });

  // Clear button
  document.getElementById('btn-clear')?.addEventListener('click', () => {
    editor.clear();
    output.textContent = 'Editor cleared';
  });

  // Destroy button
  document.getElementById('btn-destroy')?.addEventListener('click', () => {
    editor.destroy();
    output.textContent = 'Editor destroyed';
  });

  // Make editor available globally for debugging
  (window as any).editor = editor;
});
