import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="markdown-editor"
export default class extends Controller {
  static targets = ["content", "formatRadio", "helpText", "preview"]
  
  connect() {
    this.updateEditorInterface()
    
    // Add event listeners for format change
    this.formatRadioTargets.forEach(radio => {
      radio.addEventListener('change', this.updateEditorInterface.bind(this))
    })
  }
  
  updateEditorInterface() {
    const selectedFormat = this.formatRadioTargets.find(radio => radio.checked).value
    const contentElement = this.contentTarget
    
    // Update placeholder and help text based on format
    if (selectedFormat === 'markdown') {
      contentElement.placeholder = "# Page Title\n\nWrite your content in **Markdown** format..."
      contentElement.classList.add('font-mono')
      this.helpTextTarget.innerHTML = 'Content in Markdown format. See the <a href="https://www.markdownguide.org/cheat-sheet/" target="_blank" class="text-indigo-500 hover:text-indigo-600">Markdown Cheat Sheet</a> for syntax reference.'
    } else {
      contentElement.placeholder = "Page content in HTML format..."
      contentElement.classList.remove('font-mono')
      this.helpTextTarget.textContent = 'The main content of the page. HTML is supported.'
    }
  }

  // For future: real-time preview could be added with an API endpoint for rendering markdown
}