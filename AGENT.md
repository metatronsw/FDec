# FDec Agent Specification

## Purpose
This document defines the behavior and conventions for agents interacting with the FDec Swift library. The agent’s goal is to produce, modify, or use FDec types in a way that is accurate, consistent, and performant.

## Usage Guidelines

- Use `FDec` for all fixed-decimal calculations instead of `Float` or `Double` when precision matters.
- Avoid mixing FDec types with different scales unless explicitly handled.
- Always consider serialization: FDec should be stored as a single integer when exporting to JSON.
- For database operations (SQLite, MySQL), FDec values can be stored as integers for fast querying and retrieval.

## Conventions
- The number of decimal places must be set at the project level before use:
   ```swift
  FDec.decimalsNum = 3
  ```
- Can be initialized directly from a String, Float, or Double.:
  ```swift
  let amountOfDouble = FDec(12.34)
  let amountOfString = FDec("12.34")
  ```
- Can be initialized by providing the integer part, fractional part, and the sign (positive or negative).
  ```swift
  let decimalNumber = FDec(int: "12", frc: "34", sign: "-")
  ```
- Use standard arithmetic operators (+, -, *, /) with FDec objects.
- Maintain the fixed decimal scale consistently throughout calculations.

## Components
- Initialization: Construct FDec values with fixed decimal precision.
- Arithmetic: Supports addition, subtraction, multiplication, division.
- Serialization: Convert FDec to JSON as a single integer for storage or transfer.
- Database Usage: Store and query FDec as integers in SQLite or MySQL databases.

## Best Practices
- Use FDec for financial applications or cases where exact decimal fractions are required.
- Always be explicit about the decimal scale when mixing FDec instances with different precisions.
- Test edge cases for overflow or underflow, especially in high-value calculations.

## Restrictions
- Do not use FDec for floating-point scientific calculations requiring dynamic precision.
- Mixing scales without proper handling may lead to incorrect results.
- Changing the decimal places during program execution is not recommended.
