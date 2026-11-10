# Perf: Image optimization (WebP conversion + lazy loading)

**Mode:** auto  
**When to use:** Site has large JPG/PNG images hurting load time

```yaml
- id: optimize-images
  mode: auto
  branch: perf/image-optimization
  prompt: >
    Optimize all images in [DIRECTORY e.g. /images] in this project.

    Steps:
    1. Convert all .jpg and .png files to .webp using the `cwebp` or `sharp` CLI tool
       (check which is available with `which cwebp sharp`; install cwebp via brew if needed)
       Quality setting: 85 for photos, 90 for UI images
       Keep originals as fallbacks

    2. Update all HTML files to use <picture> tags:
       <picture>
         <source srcset="image.webp" type="image/webp">
         <img src="image.jpg" alt="[keep existing alt text]" loading="lazy" width="[w]" height="[h]">
       </picture>

    3. For images above the fold (first visible screen): do NOT add loading="lazy"
       For images below the fold: add loading="lazy" and add width + height attributes
       to prevent layout shift

    4. Update any CSS background-image references to use the .webp version with
       a @supports fallback:
       @supports (background-image: url('x.webp')) { .hero { background-image: url('hero.webp'); } }
       .hero { background-image: url('hero.jpg'); }

    Do not change any layout, text, or functionality.

    Done when: `find . -name "*.webp" | wc -l` matches the number of original images
    and all HTML files reference the .webp versions.
```
