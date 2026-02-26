export class AppError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly statusCode: number = 500,
    public readonly context?: Record<string, unknown>
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super('NOT_FOUND', `${resource} not found: ${id}`, 404, { resource, id });
  }
}

export class UnauthorizedError extends AppError {
  constructor(reason = 'Invalid token') {
    super('UNAUTHORIZED', reason, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(action: string) {
    super('FORBIDDEN', `Access denied: ${action}`, 403, { action });
  }
}

export class ValidationError extends AppError {
  constructor(details: unknown) {
    super('VALIDATION_ERROR', 'Invalid request body', 400, { details });
  }
}

export class ConflictError extends AppError {
  constructor(field: string, message: string) {
    super('CONFLICT', message, 409, { field });
  }
}
