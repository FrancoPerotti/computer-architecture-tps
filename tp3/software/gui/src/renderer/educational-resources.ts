import { useEffect, useState } from 'react'
import type { ProcessorProfile, StageName } from '../shared/contracts'
export interface ModuleContent {
  title: string
  description: string
  inputs: [string, string][]
  outputs: [string, string][]
  external_signals: unknown[]
  links: { title: string; url: string }[]
}
export interface InstructionContent {
  name: string
  example: string
  equation: string
  description: string
  route_description: string
  stages: {
    stage: StageName
    title: string
    description: string
    operation: string
    paragraphs: string[]
    controls: string
    blocks: string[]
  }[]
}
export interface EducationalResources {
  profile: ProcessorProfile & {
    diagram_sha256: string
    bindings_sha256: string
    observable_fields: Record<string, { path: string; bits: number }[]>
  }
  bindings: { blocks: Record<string, string>; representations?: Record<string, string[]> }
  education: {
    modules: Record<string, ModuleContent>
    instructions: Record<string, InstructionContent>
    assumptions: string[]
  }
  education_sha256: string
}
let loading: Promise<EducationalResources> | null = null
export function educationalResources(): Promise<EducationalResources> {
  return (loading ??= Promise.all(
    ['processor_profile.json', 'diagram_bindings.json', 'es/education.json'].map(async (name) => {
      const response = await fetch(`viewrv://app/content/${name}`)
      if (!response.ok) throw Error('No se pudo abrir el contenido educativo local.')
      return response.text()
    }),
  )
    .then(async ([profileText, bindingsText, educationText]) => {
      const digest = async (text: string) =>
        Array.from(
          new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))),
        )
          .map((byte) => byte.toString(16).padStart(2, '0'))
          .join('')
      const profile = JSON.parse(profileText),
        bindings = JSON.parse(bindingsText),
        education = JSON.parse(educationText)
      if (
        (await digest(bindingsText)) !== profile.bindings_sha256 ||
        !profile.observable_fields ||
        Object.keys(education.instructions).length !== 33
      )
        throw Error('El contenido educativo no coincide con el perfil local.')
      return { profile, bindings, education, education_sha256: await digest(educationText) }
    })
    .catch((error) => {
      loading = null
      throw error
    }))
}
export function useEducationalResources() {
  const [value, setValue] = useState<EducationalResources | null>(null),
    [error, setError] = useState<string | null>(null)
  useEffect(() => {
    let active = true
    void educationalResources()
      .then((value) => {
        if (active) setValue(value)
      })
      .catch((error) => {
        if (active) setError(error.message)
      })
    return () => {
      active = false
    }
  }, [])
  return { resources: value, resourceError: error }
}
