#ifndef MAIN_H
#define MAIN_H

#include "stm32f4xx_hal.h"

/* NUCLEO-F411RE board pins */
#define LD2_Pin        GPIO_PIN_5      /* green user LED */
#define LD2_GPIO_Port  GPIOA
#define B1_Pin         GPIO_PIN_13     /* blue user button (active low) */
#define B1_GPIO_Port   GPIOC

/* LED pattern: LED_PULSES x (on LED_PULSE_ON_MS, off LED_PULSE_OFF_MS), then off LED_PAUSE_MS.
 * Default: double blink - 200 on, 200 off, 200 on, 1000 off. */
#define LED_PULSES        2U
#define LED_PULSE_ON_MS   200U
#define LED_PULSE_OFF_MS  200U
#define LED_PAUSE_MS      1000U

void Error_Handler(void);

#endif /* MAIN_H */
