import { cameraLogoSvgs } from 'virtual:camera-logo-svgs'

export function drawContainedImage(
  context: CanvasRenderingContext2D,
  image: HTMLImageElement,
  x: number,
  y: number,
  width: number,
  height: number,
) {
  const imageRatio = image.naturalWidth / image.naturalHeight
  const targetRatio = width / height
  const drawWidth = imageRatio > targetRatio ? width : height * imageRatio
  const drawHeight = imageRatio > targetRatio ? width / imageRatio : height
  const drawX = x + (width - drawWidth) / 2
  const drawY = y + (height - drawHeight) / 2

  context.drawImage(image, drawX, drawY, drawWidth, drawHeight)
}

export function drawCoverImage(
  context: CanvasRenderingContext2D,
  image: HTMLImageElement,
  x: number,
  y: number,
  width: number,
  height: number,
) {
  const imageRatio = image.naturalWidth / image.naturalHeight
  const targetRatio = width / height
  const sourceWidth = imageRatio > targetRatio ? image.naturalHeight * targetRatio : image.naturalWidth
  const sourceHeight = imageRatio > targetRatio ? image.naturalHeight : image.naturalWidth / targetRatio
  const sourceX = (image.naturalWidth - sourceWidth) / 2
  const sourceY = (image.naturalHeight - sourceHeight) / 2

  context.drawImage(image, sourceX, sourceY, sourceWidth, sourceHeight, x, y, width, height)
}

export function loadImage(source: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = reject
    image.src = source
  })
}

export async function loadCanvasSafeImage(source: string) {
  if (!isSvgSource(source)) {
    return loadImage(source)
  }

  const bundledSvg = findBundledLogoSvg(source)
  if (isHarmonyRawfileSource(source) && bundledSvg) {
    return loadSanitizedSvg(bundledSvg)
  }

  try {
    const response = await fetch(source)
    if (!response.ok) {
      throw new Error(`Failed to load SVG asset: ${source}`)
    }

    return loadSanitizedSvg(await response.text())
  } catch (error) {
    if (bundledSvg) {
      return loadSanitizedSvg(bundledSvg)
    }

    throw error
  }
}

function loadSanitizedSvg(svg: string) {
  const sanitizedSvg = sanitizeSvgForCanvas(svg)
  return loadImage(`data:image/svg+xml;charset=utf-8,${encodeURIComponent(sanitizedSvg)}`)
}

function findBundledLogoSvg(source: string) {
  const fileName = getSourceFileName(source)
  return fileName ? cameraLogoSvgs[fileName] : undefined
}

function getSourceFileName(source: string) {
  const fileName = source.split(/[?#]/)[0]?.split('/').pop()
  return fileName ? decodeURIComponent(fileName) : undefined
}

function isSvgSource(source: string) {
  return source.split(/[?#]/)[0]?.toLowerCase().endsWith('.svg') ?? false
}

function isHarmonyRawfileSource(source: string) {
  return __HARMONY_RAWFILE__ || source.startsWith('resource://rawfile/')
}

function sanitizeSvgForCanvas(svg: string) {
  return svg
    .replace(/<!doctype[\s\S]*?>/gi, '')
    .replace(/<\?xml-stylesheet[\s\S]*?\?>/gi, '')
    .replace(/<script\b[\s\S]*?<\/script>/gi, '')
    .replace(/<script\b[^>]*\/>/gi, '')
    .replace(/<foreignObject\b[\s\S]*?<\/foreignObject>/gi, '')
    .replace(/\s(?:href|xlink:href)=["'](?:https?:|file:|chrome-extension:|moz-extension:|safari-extension:|\/\/)[^"']*["']/gi, '')
    .replace(/\s(?:src)=["'][^"']*["']/gi, '')
    .replace(/\son[a-z]+=["'][^"']*["']/gi, '')
}
