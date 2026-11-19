/* Cortex-M4 exception handlers. */
#include "main.h"

void NMI_Handler(void)        { while (1) { } }
void HardFault_Handler(void)  { while (1) { } }
void MemManage_Handler(void)  { while (1) { } }
void BusFault_Handler(void)   { while (1) { } }
void UsageFault_Handler(void) { while (1) { } }
void SVC_Handler(void)        { }
void DebugMon_Handler(void)   { }
void PendSV_Handler(void)     { }

/* 1 ms tick for HAL_Delay()/HAL_GetTick(). */
void SysTick_Handler(void)
{
    HAL_IncTick();
}
