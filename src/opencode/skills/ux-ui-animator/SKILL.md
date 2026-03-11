---
name: ux-ui-animator
description: UI animation patterns covering CSS transitions, keyframes, Framer Motion, React Native Reanimated, Gesture Handler, spring physics, scroll-driven animations, and reduced-motion handling
---

Guide for implementing polished, performant UI animations that enhance user experience without sacrificing accessibility or performance.

## Animation Purpose Matrix

| Purpose | Examples | Duration | Easing |
|---------|----------|----------|--------|
| Feedback | Button press, toggle, hover | 100-200ms | ease-out |
| State change | Accordion, tab switch, collapse | 200-300ms | ease-in-out |
| Entrance | Modal open, toast appear, page load | 200-400ms | ease-out |
| Exit | Modal close, toast dismiss | 150-250ms | ease-in |
| Emphasis | Pulse, shake, bounce | 300-600ms | spring/custom |
| Loading | Skeleton, spinner, shimmer | 1000-2000ms | linear/ease-in-out |
| Scroll-driven | Parallax, reveal, progress | Tied to scroll | linear |

## Performance Rules

### Composite-Only Properties

Only animate properties that trigger compositing — not layout or paint:

| Animate (Fast) | Avoid (Slow) |
|-----------------|--------------|
| `transform` | `width`, `height` |
| `opacity` | `top`, `left`, `right`, `bottom` |
| `filter` | `margin`, `padding` |
| `clip-path` | `border-width` |
| `background-color` (with `will-change`) | `font-size` |

### GPU Acceleration

```css
.animated-element {
  will-change: transform, opacity;
  transform: translateZ(0);
  backface-visibility: hidden;
}
```

- Add `will-change` only to elements about to animate — remove after
- Use `transform: translateZ(0)` to force GPU layer
- Limit GPU layers — too many cause memory issues

## CSS Transitions

### Basic Pattern

```css
.element {
  transition: transform 200ms ease-out, opacity 200ms ease-out;
}

.element:hover {
  transform: scale(1.05);
  opacity: 0.9;
}
```

### Staggered Children

```css
.list-item {
  opacity: 0;
  transform: translateY(8px);
  animation: fadeInUp 300ms ease-out forwards;
}

.list-item:nth-child(1) { animation-delay: 0ms; }
.list-item:nth-child(2) { animation-delay: 50ms; }
.list-item:nth-child(3) { animation-delay: 100ms; }
```

## CSS Keyframes

### Common Animations

```css
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes shimmer {
  from { background-position: -200% 0; }
  to { background-position: 200% 0; }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-4px); }
  75% { transform: translateX(4px); }
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
```

### Skeleton Loader

```css
.skeleton {
  background: linear-gradient(90deg, #1e1e2e 25%, #313244 50%, #1e1e2e 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s ease-in-out infinite;
  border-radius: 4px;
}
```

## Tailwind Animation Classes

### Built-in Utilities

| Class | Effect |
|-------|--------|
| `animate-spin` | Continuous rotation |
| `animate-ping` | Radar pulse |
| `animate-pulse` | Gentle opacity pulse |
| `animate-bounce` | Vertical bounce |
| `transition-all` | Transition all properties |
| `transition-colors` | Transition color properties |
| `transition-opacity` | Transition opacity |
| `transition-transform` | Transition transform |
| `duration-150` / `200` / `300` / `500` | Duration in ms |
| `ease-in` / `ease-out` / `ease-in-out` | Easing functions |
| `delay-75` / `100` / `150` / `200` | Transition delay |

### Custom Tailwind Animations

```ts
// tailwind.config.ts
{
  theme: {
    extend: {
      keyframes: {
        "fade-in": {
          from: { opacity: "0" },
          to: { opacity: "1" },
        },
        "slide-up": {
          from: { opacity: "0", transform: "translateY(8px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        "scale-in": {
          from: { opacity: "0", transform: "scale(0.95)" },
          to: { opacity: "1", transform: "scale(1)" },
        },
      },
      animation: {
        "fade-in": "fade-in 200ms ease-out",
        "slide-up": "slide-up 300ms ease-out",
        "scale-in": "scale-in 200ms ease-out",
      },
    },
  },
}
```

## Framer Motion

### Basic Presence

```tsx
<motion.div
  initial={{ opacity: 0, y: 8 }}
  animate={{ opacity: 1, y: 0 }}
  exit={{ opacity: 0, y: -8 }}
  transition={{ duration: 0.2, ease: "easeOut" }}
/>
```

### AnimatePresence for Mount/Unmount

```tsx
<AnimatePresence mode="wait">
  {isVisible && (
    <motion.div
      key="modal"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ duration: 0.2 }}
    />
  )}
</AnimatePresence>
```

### Layout Animations

```tsx
<motion.div layout layoutId="card" transition={{ type: "spring", stiffness: 300, damping: 30 }} />
```

### Staggered Children

```tsx
const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.05 },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 8 },
  visible: { opacity: 1, y: 0 },
}

<motion.ul variants={containerVariants} initial="hidden" animate="visible">
  {items.map((item) => (
    <motion.li key={item.id} variants={itemVariants} />
  ))}
</motion.ul>
```

### Gesture Animations

```tsx
<motion.button
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  transition={{ type: "spring", stiffness: 400, damping: 17 }}
/>
```

### Scroll-Triggered

```tsx
<motion.div
  initial={{ opacity: 0, y: 40 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, margin: "-100px" }}
  transition={{ duration: 0.5, ease: "easeOut" }}
/>
```

## Spring Physics

### When to Use Springs vs Easing

| Use Springs | Use Easing |
|-------------|------------|
| Interactive/draggable elements | Simple state transitions |
| Layout shifts | Fade in/out |
| Gesture-driven motion | Loading animations |
| Anything needing natural feel | Timed sequences |

### Spring Configuration Presets

| Preset | Stiffness | Damping | Feel |
|--------|-----------|---------|------|
| Gentle | 120 | 14 | Soft, slow settle |
| Default | 170 | 26 | Balanced |
| Wobbly | 180 | 12 | Bouncy, playful |
| Stiff | 300 | 30 | Snappy, minimal overshoot |
| Rigid | 500 | 35 | Very fast, almost no bounce |

```tsx
transition={{ type: "spring", stiffness: 300, damping: 30 }}
```

## Scroll-Driven Animations (CSS)

### Scroll Progress

```css
@keyframes reveal {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

.scroll-reveal {
  animation: reveal linear both;
  animation-timeline: view();
  animation-range: entry 0% entry 100%;
}
```

### Scroll-Linked Progress Bar

```css
.progress-bar {
  transform-origin: left;
  animation: grow linear;
  animation-timeline: scroll();
}

@keyframes grow {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}
```

## Reduced Motion

Always respect `prefers-reduced-motion`:

### CSS

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Framer Motion

```tsx
const prefersReducedMotion = useReducedMotion()

<motion.div
  initial={prefersReducedMotion ? false : { opacity: 0, y: 8 }}
  animate={{ opacity: 1, y: 0 }}
  transition={prefersReducedMotion ? { duration: 0 } : { duration: 0.2 }}
/>
```

### React Hook

```tsx
const usePrefersReducedMotion = () => {
  const [prefersReduced, setPrefersReduced] = useState(
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  )

  useEffect(() => {
    const mql = window.matchMedia("(prefers-reduced-motion: reduce)")
    const handler = (event: MediaQueryListEvent) => setPrefersReduced(event.matches)
    mql.addEventListener("change", handler)
    return () => mql.removeEventListener("change", handler)
  }, [])

  return prefersReduced
}
```

## Common UI Animation Patterns

### Modal / Dialog

```tsx
<AnimatePresence>
  {isOpen && (
    <>
      <motion.div
        className="fixed inset-0 bg-black/50"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
      />
      <motion.div
        className="fixed inset-0 flex items-center justify-center"
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
      />
    </>
  )}
</AnimatePresence>
```

### Toast / Notification

```tsx
<motion.div
  initial={{ opacity: 0, y: -16, scale: 0.95 }}
  animate={{ opacity: 1, y: 0, scale: 1 }}
  exit={{ opacity: 0, y: -16, scale: 0.95 }}
  transition={{ type: "spring", stiffness: 400, damping: 25 }}
/>
```

### Accordion / Collapse

```tsx
<motion.div
  initial={false}
  animate={{ height: isOpen ? "auto" : 0 }}
  transition={{ duration: 0.2, ease: "easeInOut" }}
  style={{ overflow: "hidden" }}
/>
```

### Page Transition

```tsx
const pageVariants = {
  initial: { opacity: 0, x: 20 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -20 },
}

<AnimatePresence mode="wait">
  <motion.div
    key={pathname}
    variants={pageVariants}
    initial="initial"
    animate="animate"
    exit="exit"
    transition={{ duration: 0.2 }}
  />
</AnimatePresence>
```

### Skeleton to Content

```tsx
<AnimatePresence mode="wait">
  {isLoading ? (
    <motion.div
      key="skeleton"
      className="animate-pulse bg-surface0 rounded"
      exit={{ opacity: 0 }}
      transition={{ duration: 0.15 }}
    />
  ) : (
    <motion.div
      key="content"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.2 }}
    />
  )}
</AnimatePresence>
```

## Animation Checklist

- [ ] Animation has a clear UX purpose (feedback, orientation, delight)
- [ ] Duration matches the animation purpose (see matrix above)
- [ ] Only composite properties are animated (transform, opacity)
- [ ] `prefers-reduced-motion` disables or simplifies all animations
- [ ] No animation flashes more than 3 times per second
- [ ] Entrance/exit animations are paired (what animates in, animates out)
- [ ] Stagger delays are short (30-80ms) to feel connected, not slow
- [ ] Spring physics used for interactive/gesture-driven motion
- [ ] `will-change` applied sparingly and removed after animation
- [ ] Animations don't block user interaction or content access

## React Native Reanimated

### Shared Values & Animated Styles

```tsx
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from "react-native-reanimated"

const CardComponent = () => {
  const scale = useSharedValue(1)
  const opacity = useSharedValue(1)

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }))

  const handlePress = () => {
    scale.value = withSpring(1.1, { damping: 15, stiffness: 150 })
  }

  return <Animated.View style={animatedStyle} />
}
```

### Animation Functions

| Function | Use Case | Config |
|----------|----------|--------|
| `withSpring` | Natural, bouncy motion | `{ damping, stiffness, mass }` |
| `withTiming` | Timed transitions | `{ duration, easing }` |
| `withDelay` | Delayed start | `withDelay(200, withSpring(...))` |
| `withSequence` | Chained animations | `withSequence(withTiming(1.2), withTiming(1))` |
| `withRepeat` | Looping | `withRepeat(withTiming(1), -1, true)` |
| `withDecay` | Momentum/fling | `{ velocity, deceleration }` |

### Entering & Exiting Animations

```tsx
import { FadeIn, FadeOut, SlideInRight, SlideOutLeft } from "react-native-reanimated"

<Animated.View entering={FadeIn.duration(300)} exiting={FadeOut.duration(200)}>
  <Text>Animated content</Text>
</Animated.View>

<Animated.View
  entering={SlideInRight.springify().damping(15)}
  exiting={SlideOutLeft.duration(200)}
/>
```

### Layout Animations

```tsx
import { LinearTransition, SequencedTransition } from "react-native-reanimated"

<Animated.View layout={LinearTransition.springify()}>
  {items.map((item) => (
    <Animated.View
      key={item.id}
      entering={FadeIn}
      exiting={FadeOut}
      layout={LinearTransition}
    />
  ))}
</Animated.View>
```

### Interpolation

```tsx
import { interpolate, Extrapolation } from "react-native-reanimated"

const animatedStyle = useAnimatedStyle(() => ({
  opacity: interpolate(scrollY.value, [0, 100], [1, 0], Extrapolation.CLAMP),
  transform: [
    { translateY: interpolate(scrollY.value, [0, 100], [0, -50], Extrapolation.CLAMP) },
  ],
}))
```

### Scroll-Driven (Reanimated)

```tsx
import Animated, {
  useAnimatedScrollHandler,
  useSharedValue,
} from "react-native-reanimated"

const scrollY = useSharedValue(0)

const scrollHandler = useAnimatedScrollHandler({
  onScroll: (event) => {
    scrollY.value = event.contentOffset.y
  },
})

<Animated.ScrollView onScroll={scrollHandler} scrollEventThrottle={16}>
  {children}
</Animated.ScrollView>
```

## React Native Gesture Handler

### Basic Gestures

```tsx
import { Gesture, GestureDetector } from "react-native-gesture-handler"
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from "react-native-reanimated"

const DraggableCard = () => {
  const translateX = useSharedValue(0)
  const translateY = useSharedValue(0)

  const pan = Gesture.Pan()
    .onUpdate((event) => {
      translateX.value = event.translationX
      translateY.value = event.translationY
    })
    .onEnd(() => {
      translateX.value = withSpring(0)
      translateY.value = withSpring(0)
    })

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
    ],
  }))

  return (
    <GestureDetector gesture={pan}>
      <Animated.View style={animatedStyle} />
    </GestureDetector>
  )
}
```

### Gesture Types

| Gesture | Use Case |
|---------|----------|
| `Gesture.Tap()` | Single/double tap detection |
| `Gesture.Pan()` | Drag and swipe |
| `Gesture.Pinch()` | Zoom in/out |
| `Gesture.Rotation()` | Two-finger rotation |
| `Gesture.LongPress()` | Press and hold |
| `Gesture.Fling()` | Quick swipe in direction |

### Composing Gestures

```tsx
const pinch = Gesture.Pinch().onUpdate((e) => {
  scale.value = e.scale
})

const pan = Gesture.Pan().onUpdate((e) => {
  translateX.value = e.translationX
  translateY.value = e.translationY
})

const composed = Gesture.Simultaneous(pinch, pan)

<GestureDetector gesture={composed}>
  <Animated.View style={animatedStyle} />
</GestureDetector>
```

### Swipe-to-Delete

```tsx
const SwipeableRow = ({ onDelete, children }: SwipeableRowProps) => {
  const translateX = useSharedValue(0)
  const deleteThreshold = -80

  const pan = Gesture.Pan()
    .activeOffsetX([-10, 10])
    .onUpdate((e) => {
      translateX.value = Math.min(0, e.translationX)
    })
    .onEnd(() => {
      if (translateX.value < deleteThreshold) {
        translateX.value = withTiming(-200)
        runOnJS(onDelete)()
      } else {
        translateX.value = withSpring(0)
      }
    })

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }))

  return (
    <GestureDetector gesture={pan}>
      <Animated.View style={animatedStyle}>{children}</Animated.View>
    </GestureDetector>
  )
}
```

## React Native Reduced Motion

```tsx
import { useReducedMotion } from "react-native-reanimated"
import { AccessibilityInfo } from "react-native"

const prefersReducedMotion = useReducedMotion()

const animatedStyle = useAnimatedStyle(() => ({
  transform: [
    {
      scale: prefersReducedMotion
        ? 1
        : withSpring(scale.value, { damping: 15 }),
    },
  ],
}))
```

- Always check `useReducedMotion()` from Reanimated
- Disable or simplify animations when reduced motion is preferred
- Ensure essential state changes are still communicated without animation
