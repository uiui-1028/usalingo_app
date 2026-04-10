import AuthForm from "./auth-form";

type AuthPageProps = {
  searchParams: Promise<{ next?: string }>;
};

export default async function AuthPage({ searchParams }: AuthPageProps) {
  const { next } = await searchParams;
  return <AuthForm nextPath={next ?? "/dashboard"} />;
}
