
# 1. Introduction

In this chapter, we introduce the core ideas of **[Topic]**.

---

## 1.1 Descriptive Text

This book uses plain Markdown so it can be:

- Read directly on the web
- Exported or printed to **PDF**
- Mixed with **code**, **figures**, **videos**, and **audio** seamlessly

> In software engineering education, using open materials allows students to
> inspect not only the final text but also the structure of the book, its
> version history, and collaborative contributions.

---

## 1.2 Images

Store images under `docs/figures/` and reference them with relative paths:

![Example diagram of the system](../figures/example-diagram.png "System Architecture – Example")

Rendered:

![Example diagram of the system](../figures/example-diagram.png "System Architecture – Example")

> ℹ️ Replace `example-diagram.png` with your actual diagram.

---

## 1.3 Source Code in Different Languages

Below are examples of fenced code blocks with language tags for syntax highlighting.

=== "Python"

```python
def greet(name: str) -> str:
    """Return a greeting message."""
    return f"Hello, {name}!"

if __name__ == "__main__":
    print(greet("Student"))
```

=== "JavaScript"

```javascript
function sum(a, b) {
  return a + b;
}

console.log("Result:", sum(2, 3));
```

=== "Java"

```java
public class Hello {
    public static void main(String[] args) {
        String name = (args.length > 0) ? args[0] : "Student";
        System.out.println("Hello, " + name + "!");
    }
}
```

You can add more languages as needed: `c`, `cpp`, `bash`, `html`, etc.

---

## 1.4 Video (YouTube or Other Streaming)

Markdown has no native `<video>` tag, but we can:

### A. Simple Link

```markdown
Watch the introduction video:  
https://www.youtube.com/watch?v=YOUR_VIDEO_ID
```

Rendered:

Watch the introduction video:
[https://www.youtube.com/watch?v=YOUR_VIDEO_ID](https://www.youtube.com/watch?v=YOUR_VIDEO_ID)

### B. Clickable Thumbnail

Assuming you have `docs/figures/example-video-thumb.png`:

```markdown
[![Watch the video](../figures/example-video-thumb.png)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID "Intro Video")
```

Rendered:

[![Watch the video](../figures/example-video-thumb.png)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID "Intro Video")

---

## 1.5 Audio (Podcast or Lecture)

### Simple External Link

```markdown
Listen to the companion podcast episode:  
https://example.com/podcast/episode-1
```

Rendered:

Listen to the companion podcast episode:
[https://example.com/podcast/episode-1](https://example.com/podcast/episode-1)

### Embedded Local Audio File

If you place `example-audio.mp3` in `docs/media/`:

```html
<audio controls>
  <source src="../media/example-audio.mp3" type="audio/mpeg">
  Your browser does not support the audio element.
</audio>
```

Rendered:

<audio controls>
  <source src="../media/example-audio.mp3" type="audio/mpeg">
  Your browser does not support the audio element.
</audio>

Most modern browsers will show a built-in audio player.

---

## 1.6 “Playground” Exercise

!!! example "Try it yourself"
1. Copy the Python `greet` function from this chapter.
2. Modify it to accept an optional parameter `course`, and print
`"Hello, <name>, welcome to <course>!"`.
3. Run it in your local environment or an online IDE (e.g., Replit, GitHub Codespaces).

---

## 1.7 Quick Quiz

!!! question "Concept check"
1. Why is using Markdown a good choice for open textbooks?
2. What are the advantages of hosting the book on GitHub?
3. How can a student generate a PDF from this book?

??? info "Suggested answers (click to expand)"
1. Markdown is simple, version-controllable, and tool-agnostic, and it can be converted to HTML/PDF and many other formats.
2. GitHub provides version control, collaboration, issue tracking, and free hosting via GitHub Pages.
3. Use the **“Print / Save PDF”** menu item, then the browser’s **Print → Save as PDF** option.

---

[:material-arrow-left: Back to Preface](../preface.md)
[:material-arrow-right: Go to Chapter 2 – First Steps](02-first-steps.md)

