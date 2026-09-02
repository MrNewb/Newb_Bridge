const MARKDOWN_PATTERN = /(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/g

function renderLine(text) {
  const parts = text.split(MARKDOWN_PATTERN).filter(Boolean)

  return parts.map((part, index) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={index}>{part.slice(2, -2)}</strong>
    }

    if (part.startsWith('*') && part.endsWith('*')) {
      return <em key={index}>{part.slice(1, -1)}</em>
    }

    if (part.startsWith('`') && part.endsWith('`')) {
      return <code key={index}>{part.slice(1, -1)}</code>
    }

    return <span key={index}>{part}</span>
  })
}

function renderInlineMarkdown(text) {
  const lines = String(text).split('\n')

  return lines.map((line, lineIndex) => (
    <span key={lineIndex}>
      {lineIndex > 0 ? <br /> : null}
      {renderLine(line)}
    </span>
  ))
}

export default function DialogueMarkdown({ text, className }) {
  if (!text) return null

  return <span className={className}>{renderInlineMarkdown(text)}</span>
}
