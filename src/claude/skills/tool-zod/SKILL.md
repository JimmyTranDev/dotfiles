---
name: tool-zod
description: Zod schema patterns covering validation, transforms, refinements, coercion, discriminated unions, recursive schemas, and integration with forms and APIs
---

## Basic Schemas

```ts
import { z } from "zod";

const stringSchema = z.string().min(1).max(255);
const emailSchema = z.string().email();
const urlSchema = z.string().url();
const uuidSchema = z.string().uuid();
const numberSchema = z.number().int().positive();
const booleanSchema = z.boolean();
const dateSchema = z.date();
const enumSchema = z.enum(["admin", "user", "guest"]);
const literalSchema = z.literal("active");
const nullableSchema = z.string().nullable();
const optionalSchema = z.string().optional();
```

Type inference:

```ts
const UserSchema = z.object({ name: z.string(), age: z.number() });
type User = z.infer<typeof UserSchema>;
```

## Object Schemas

```ts
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(["admin", "member"]).default("member"),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

const PartialUser = CreateUserSchema.partial();
const RequiredUser = CreateUserSchema.required();
const PickedUser = CreateUserSchema.pick({ email: true, name: true });
const OmittedUser = CreateUserSchema.omit({ metadata: true });
const ExtendedUser = CreateUserSchema.extend({ id: z.string().uuid() });
const MergedSchema = CreateUserSchema.merge(z.object({ createdAt: z.date() }));

const StrictSchema = z.object({ name: z.string() }).strict();
const PassthroughSchema = z.object({ name: z.string() }).passthrough();
```

## Array/Tuple Schemas

```ts
const TagsSchema = z.array(z.string()).min(1).max(10);
const UniqueIdsSchema = z.array(z.string().uuid()).nonempty();
const TupleSchema = z.tuple([z.string(), z.number(), z.boolean()]);
const CoordinateSchema = z.tuple([z.number(), z.number()]);
```

## Transforms

```ts
const TrimmedString = z.string().trim();
const LowercaseEmail = z.string().email().transform((val) => val.toLowerCase());
const StringToNumber = z.string().transform((val) => parseInt(val, 10));
const DateToIso = z.date().transform((date) => date.toISOString());

const ApiResponse = z.object({
  created_at: z.string().transform((val) => new Date(val)),
  full_name: z.string().transform((val) => {
    const [first, ...rest] = val.split(" ");
    return { firstName: first, lastName: rest.join(" ") };
  }),
});
```

## Refinements

```ts
const PasswordSchema = z
  .string()
  .min(8)
  .refine((val) => /[A-Z]/.test(val), { message: "Must contain uppercase" })
  .refine((val) => /[0-9]/.test(val), { message: "Must contain number" });

const DateRangeSchema = z
  .object({
    startDate: z.date(),
    endDate: z.date(),
  })
  .refine((data) => data.endDate > data.startDate, {
    message: "End date must be after start date",
    path: ["endDate"],
  });

const superRefineExample = z.string().superRefine((val, ctx) => {
  if (val.length < 3) {
    ctx.addIssue({
      code: z.ZodIssueCode.too_small,
      minimum: 3,
      type: "string",
      inclusive: true,
      message: "Too short",
    });
  }
});
```

## Coercion

```ts
const CoercedNumber = z.coerce.number();
const CoercedBoolean = z.coerce.boolean();
const CoercedDate = z.coerce.date();
const CoercedString = z.coerce.string();
```

| Input | `z.coerce.number()` | Result |
|-------|---------------------|--------|
| `"42"` | ✅ | `42` |
| `""` | ✅ | `0` |
| `null` | ✅ | `0` |
| `"abc"` | ❌ | NaN → fails |

## Discriminated Unions

```ts
const EventSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("click"), x: z.number(), y: z.number() }),
  z.object({ type: z.literal("keypress"), key: z.string() }),
  z.object({ type: z.literal("scroll"), deltaY: z.number() }),
]);

type Event = z.infer<typeof EventSchema>;

const NotificationSchema = z.discriminatedUnion("channel", [
  z.object({ channel: z.literal("email"), to: z.string().email(), subject: z.string() }),
  z.object({ channel: z.literal("sms"), phone: z.string(), body: z.string() }),
  z.object({ channel: z.literal("push"), token: z.string(), title: z.string() }),
]);
```

## Recursive Schemas

```ts
const CategorySchema: z.ZodType<Category> = z.lazy(() =>
  z.object({
    id: z.string(),
    name: z.string(),
    children: z.array(CategorySchema),
  })
);

interface Category {
  id: string;
  name: string;
  children: Category[];
}

const JsonValueSchema: z.ZodType<JsonValue> = z.lazy(() =>
  z.union([z.string(), z.number(), z.boolean(), z.null(), z.array(JsonValueSchema), z.record(JsonValueSchema)])
);

type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };
```

## Error Handling

```ts
const result = UserSchema.safeParse(input);

if (!result.success) {
  const formatted = result.error.flatten();
  console.log(formatted.fieldErrors);
  return;
}

const user = result.data;
```

Custom error map:

```ts
const schema = z.object({
  email: z.string({ required_error: "Email is required" }).email("Invalid email format"),
  age: z.number({ invalid_type_error: "Age must be a number" }).min(18, "Must be 18+"),
});
```

Flatten vs format:

| Method | Output |
|--------|--------|
| `error.flatten()` | `{ formErrors: [], fieldErrors: { field: ["msg"] } }` |
| `error.format()` | Nested object with `_errors` arrays |
| `error.issues` | Raw issue array with path, code, message |

## Integration Patterns

### React Hook Form

```ts
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";

const FormSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

type FormData = z.infer<typeof FormSchema>;

export function LoginForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(FormSchema),
  });

  const onSubmit = (data: FormData) => {
    console.log(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register("email")} />
      {errors.email && <span>{errors.email.message}</span>}
      <input type="password" {...register("password")} />
      {errors.password && <span>{errors.password.message}</span>}
      <button type="submit">Login</button>
    </form>
  );
}
```

### API Validation

```ts
export function validateRequest<T>(schema: z.ZodSchema<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw new ValidationError(result.error.flatten().fieldErrors);
  }
  return result.data;
}

const QueryParamsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  sort: z.enum(["asc", "desc"]).default("desc"),
  search: z.string().optional(),
});
```

### tRPC

```ts
export const userRouter = router({
  create: publicProcedure
    .input(CreateUserSchema)
    .mutation(({ input }) => createUser(input)),
  list: publicProcedure
    .input(z.object({ cursor: z.string().optional(), limit: z.number().default(20) }))
    .query(({ input }) => listUsers(input)),
});
```
