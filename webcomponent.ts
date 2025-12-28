// WebComponent mode entry point

// Import MoonBit webcomponent module
import 'mbt:internal/app/webcomponent';

// Wait for custom element to be defined
customElements.whenDefined('moonlight-editor').then(() => {
  const output = document.getElementById('output');
  if (output) {
    output.textContent = 'WebComponent registered successfully!';
  }

  // Get editor elements
  const editor1 = document.getElementById('editor1') as any;
  const editor2 = document.getElementById('editor2') as any;

  // Export SVG button
  document.getElementById('btn-export')?.addEventListener('click', () => {
    const svg = editor1?.exportSvg?.() || '<svg></svg>';
    if (output) {
      output.textContent = svg;
    }
  });

  // Clear button
  document.getElementById('btn-clear')?.addEventListener('click', () => {
    editor1?.clear?.();
    editor2?.clear?.();
    if (output) {
      output.textContent = 'Editors cleared';
    }
  });
});
