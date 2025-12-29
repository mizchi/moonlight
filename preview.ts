// Preview mode entry point

// Import MoonBit preview module
import 'mbt:mizchi/moonlight/preview';

// Sample SVG content
const sampleSvg = `<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="30" height="30" fill="#4CAF50"/>
  <circle cx="70" cy="50" r="20" fill="#2196F3"/>
</svg>`;

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
  const output = document.getElementById('output');

  if (!output) {
    console.error('Output element not found');
    return;
  }

  // Create preview instances
  const container1 = document.getElementById('preview1');
  const container2 = document.getElementById('preview2');

  if (!container1 || !container2) {
    console.error('Preview containers not found');
    return;
  }

  const preview1 = (window as any).MoonlightPreview.create(container1, sampleSvg, {
    width: 300,
    height: 200
  });

  const preview2 = (window as any).MoonlightPreview.create(container2, sampleSvg, {
    width: 400,
    height: 300
  });

  output.textContent = 'Previews created successfully!';

  // Open buttons
  document.getElementById('btn-open1')?.addEventListener('click', () => {
    preview1.openEditor();
    output.textContent = 'Opened Preview 1 editor';
  });

  document.getElementById('btn-open2')?.addEventListener('click', () => {
    preview2.openEditor();
    output.textContent = 'Opened Preview 2 editor';
  });

  // Make previews available globally for debugging
  (window as any).preview1 = preview1;
  (window as any).preview2 = preview2;
});
