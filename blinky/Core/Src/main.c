/*
 * NUCLEO-F411RE LED blink (STM32 HAL).
 * LD2 (PA5): double blink (200 ms on, 200 ms off, 200 ms on), then 1 s off. SYSCLK = 100 MHz from HSI via PLL.
 */
#include "main.h"

static void SystemClock_Config(void);
static void GPIO_Init(void);

volatile uint32_t blink_count = 0;  /* watch this in the debugger */

int main(void)
{
    HAL_Init();                 /* reset peripherals, init flash + 1 ms SysTick */
    SystemClock_Config();
    GPIO_Init();

    while (1) {
        for (uint32_t i = 0; i < LED_PULSES; i++) {
            HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_SET);
            HAL_Delay(LED_PULSE_ON_MS);
            HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);
            if (i + 1U < LED_PULSES) {
                HAL_Delay(LED_PULSE_OFF_MS);   /* gap between pulses */
            }
        }
        blink_count++;                         /* one full pattern done */
        HAL_Delay(LED_PAUSE_MS);
    }
}

/*
 * HSI 16 MHz -> PLLM 16 -> 1 MHz -> PLLN 200 -> 200 MHz -> PLLP 2 -> 100 MHz SYSCLK.
 * AHB 100 MHz, APB1 50 MHz (max), APB2 100 MHz. Flash: 3 wait states @ 3.3 V.
 */
static void SystemClock_Config(void)
{
    RCC_OscInitTypeDef osc = {0};
    RCC_ClkInitTypeDef clk = {0};

    __HAL_RCC_PWR_CLK_ENABLE();
    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

    osc.OscillatorType      = RCC_OSCILLATORTYPE_HSI;
    osc.HSIState            = RCC_HSI_ON;
    osc.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
    osc.PLL.PLLState        = RCC_PLL_ON;
    osc.PLL.PLLSource       = RCC_PLLSOURCE_HSI;
    osc.PLL.PLLM            = 16;
    osc.PLL.PLLN            = 200;
    osc.PLL.PLLP            = RCC_PLLP_DIV2;
    osc.PLL.PLLQ            = 4;
    if (HAL_RCC_OscConfig(&osc) != HAL_OK) {
        Error_Handler();
    }

    clk.ClockType      = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK |
                         RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
    clk.SYSCLKSource   = RCC_SYSCLKSOURCE_PLLCLK;
    clk.AHBCLKDivider  = RCC_SYSCLK_DIV1;
    clk.APB1CLKDivider = RCC_HCLK_DIV2;
    clk.APB2CLKDivider = RCC_HCLK_DIV1;
    if (HAL_RCC_ClockConfig(&clk, FLASH_LATENCY_3) != HAL_OK) {
        Error_Handler();
    }
}

static void GPIO_Init(void)
{
    GPIO_InitTypeDef gpio = {0};

    __HAL_RCC_GPIOA_CLK_ENABLE();
    HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);

    gpio.Pin   = LD2_Pin;
    gpio.Mode  = GPIO_MODE_OUTPUT_PP;
    gpio.Pull  = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(LD2_GPIO_Port, &gpio);
}

/* Fatal error: stop here with interrupts off (LED stays in its last state). */
void Error_Handler(void)
{
    __disable_irq();
    while (1) {
    }
}

#ifdef USE_FULL_ASSERT
void assert_failed(uint8_t *file, uint32_t line)
{
    (void)file;
    (void)line;
    Error_Handler();
}
#endif
