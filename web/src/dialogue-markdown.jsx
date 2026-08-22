const MARKDOWN_PATTERN = /(\*\*[^*]+\*\*|\*[^*]+\*)/g

function renderInlineMarkdown(text) {
  const parts = text.split(MARKDOWN_PATTERN).filter(Boolean)

  return parts.map((part, index) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={index}>{part.slice(2, -2)}</strong>
    }

    if (part.startsWith('*') && part.endsWith('*')) {
      return <em key={index}>{part.slice(1, -1)}</em>
    }

    return <span key={index}>{part}</span>
  })
}

export default function DialogueMarkdown({ text, className }) {
  if (!text) return null

  return <span className={className}>{renderInlineMarkdown(text)}</span>
}
