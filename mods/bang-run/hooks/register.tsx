import type { Register } from 'claude-code'

const INLINE = /`!\s*([A-Za-z0-9_.~/$"'-][^`\n]*?)\s*`/g
const FENCE = /```[^\n]*\n([\s\S]*?)```/g
const FENCED_LINE = /^\s*!\s*([A-Za-z0-9_.~/$"'-].*?)\s*$/

const OUTPUT_LIMIT = 30000

function bangCommands(text: string): string[] {
  const found = new Set<string>()
  for (const [, command = ''] of text.matchAll(INLINE)) found.add(command)
  for (const [, body = ''] of text.matchAll(FENCE)) {
    for (const line of body.split('\n')) {
      const [, command] = FENCED_LINE.exec(line) ?? []
      if (command) found.add(command)
    }
  }
  return [...found]
}

function clip(text: string, limit: number): string {
  return text.length > limit ? `${text.slice(0, limit)}\n… (${text.length - limit} more characters)` : text
}

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const commands = bangCommands(e.props.text)
    if (commands.length === 0) return next(e)

    const engine = await next(e)
    const { Box, Button, Text } = $.ui.resolve(e)

    const run = async (command: string) => {
      const shell = (await $.env.get('SHELL')) ?? '/bin/sh'
      $.ui.status(`running: ${command}`)
      let stdout = ''
      let stderr = ''
      let exitCode: number
      try {
        const result = await $.process.run([shell, '-lc', command], { timeoutMs: 600000 })
        ;({ stdout, stderr, exitCode } = result)
      } catch (error) {
        stderr = String(error)
        exitCode = -1
      } finally {
        $.ui.status(undefined)
      }

      const output = [stdout.trimEnd(), stderr.trimEnd()].filter(Boolean).join('\n')
      await $.prompt.submit({
        text: `I ran \`${command}\` (exit ${exitCode}):\n\n\`\`\`\n${clip(output || '(no output)', OUTPUT_LIMIT)}\n\`\`\``,
        asUser: true,
      })
    }

    return (
      <Box flexDirection="column">
        {engine}
        {commands.map((command, i) => (
          <Box flexDirection="row" gap={1} marginLeft={2}>
            <Button key={`run-${i}`} variant="primary" label="▶ run" onPress={() => run(command)} />
            <Text dimColor>{command}</Text>
          </Box>
        ))}
      </Box>
    )
  })
}
