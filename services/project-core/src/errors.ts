export class ProjectOperationError extends Error {
  constructor(
    readonly status: 403 | 409 | 422 | 503,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ProjectOperationError";
  }
}
