# Known Android Reference Fixes

This document records confirmed behavior that takes precedence over the Android reference snapshot. Add future fixes as separate sections using the same **Android reference bug** and **Correct intended behavior** structure.

## Plus English learning-language initialization

**Android reference bug:** A fresh plus-english-only installation with an English UI can initialize Hebrew as the learned language while the learning-language selector is hidden.

**Correct intended behavior:**

- Minik Plus English always learns English.
- Hebrew is never a valid learned-language state for this product.
- Stored Hebrew learning-language state must not be restored for this product.

The iOS implementation must not copy the Android bug.

## Dehumidifier vocabulary artwork

**Android reference bug:** The production `dehumidifier.webp` resembles a pump
bottle or liquid dispenser and does not communicate a household dehumidifier.

**Correct intended behavior:** The iOS vocabulary image shows a recognizable
upright dehumidifier with an air-intake grille and a distinct removable water
reservoir. It must not use humidifier mist, bottle, dispenser, or generic air
purifier imagery.

## Helix vocabulary artwork

**Android reference bug:** The production `helix.webp` depicts a film reel with
loose film instead of a geometric helix.

**Correct intended behavior:** The iOS vocabulary image shows one continuous
three-dimensional coil making repeated turns around an invisible axis. It must
not depict film, a flat spiral, a DNA double helix, or a spring attached to
another object.
