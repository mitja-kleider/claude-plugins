import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'

const engineDraws = (on: On) =>
  on('ui.render', (_$, e) => ({ type: 'Markdown', props: { text: String((e.props as { text: string }).text) } }))

const REPLY = 'Log in first, then retry:\n\n`! gcloud auth login`\n\n```\n! tsh login --proxy=x\n```'

for (const surface of ['terminal', 'desktop'] as const) {
  test(`${surface}: draws a run button per bang command`, async ($, on) => {
    // Given
    engineDraws(on)
    const ui = await $.ui.mount({
      plugin: 'bang-run',
      surface,
      component: 'AssistantMessage',
      props: { text: REPLY, isFirstOfReply: true },
    })

    // Then
    expect(await ui.find({ key: 'run-0' })).toBeDefined()
    expect(await ui.find({ key: 'run-1' })).toBeDefined()
    expect(await ui.find({ key: 'run-2' })).toBeUndefined()
  })

  test(`${surface}: leaves a reply without bang commands alone`, async ($, on) => {
    // Given
    engineDraws(on)
    const ui = await $.ui.mount({
      plugin: 'bang-run',
      surface,
      component: 'AssistantMessage',
      props: { text: 'Use `a != b` here.', isFirstOfReply: true },
    })

    // Then
    expect(await ui.findAll({ type: 'Button' })).toHaveLength(0)
  })

  test(`${surface}: run executes the command and submits its output`, async ($, on) => {
    // Given
    engineDraws(on)
    mock.env(on, { SHELL: '/bin/zsh' })
    on('ui.status', () => ({ value: undefined }))
    const submitted: string[] = []
    on('prompt.submit', (_$, e) => {
      submitted.push(e.text)
      return { text: e.text }
    })
    const calls: (readonly string[])[] = []
    on('process.run', (_$, e) => {
      calls.push(e.argv)
      return {
        value: { exitCode: 0, stdout: 'hi\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
      }
    })
    const ui = await $.ui.mount({
      plugin: 'bang-run',
      surface,
      component: 'AssistantMessage',
      props: { text: 'Try `! echo hi`', isFirstOfReply: true },
    })

    // When
    await ui.press({ key: 'run-0' })

    // Then
    expect(calls).toEqual([['/bin/zsh', '-lc', 'echo hi']])
    expect(submitted).toEqual(['I ran `echo hi` (exit 0):\n\n```\nhi\n```'])
  })
}
